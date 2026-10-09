import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { randomInt } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { TokensService } from '../tokens/tokens.service';
import { UsersService, validateBirthDate } from '../users/users.service';
import { LoginDto, RegisterDto, ResetPasswordDto, SocialCompleteDto, SocialLoginDto } from '../users/dto';
import { MailService } from './mail.service';
import { SocialIdentity, SocialProvider, SocialVerifierService } from './social-verifier.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly users: UsersService,
    private readonly tokens: TokensService,
    private readonly mail: MailService,
    private readonly social: SocialVerifierService,
  ) {}

  /** Posle svake uspešne prijave: token sesije + dnevna nagrada ako je prva prijava danas. */
  private async session(user: User) {
    if (user.isBlocked) {
      throw new ForbiddenException(
        user.blockedReason ? `Nalog je blokiran: ${user.blockedReason}` : 'Nalog je blokiran.',
      );
    }
    const daily = await this.tokens.claimDaily(user.id);
    const fresh = await this.prisma.user.update({ where: { id: user.id }, data: { lastSeenAt: new Date() } });
    const accessToken = await this.jwt.signAsync({ sub: user.id, role: user.role });
    return { accessToken, user: await this.users.me(fresh), dailyReward: daily };
  }

  async register(dto: RegisterDto) {
    if (dto.password !== dto.passwordConfirm) throw new BadRequestException('Lozinke se ne poklapaju.');
    const birthDate = validateBirthDate(dto.birthDate);
    await this.users.assertUsernameFree(dto.username);
    await this.users.assertEmailFree(dto.email);
    const user = await this.prisma.user.create({
      data: {
        username: dto.username,
        usernameLower: dto.username.toLowerCase(),
        fullName: dto.fullName,
        gender: dto.gender,
        birthDate,
        email: dto.email.toLowerCase(),
        phone: dto.phone || null,
        passwordHash: await bcrypt.hash(dto.password, 12),
      },
    });
    return this.session(user);
  }

  async login(dto: LoginDto) {
    const login = dto.login.toLowerCase();
    const user = await this.prisma.user.findFirst({
      where: { deletedAt: null, OR: [{ usernameLower: login }, { email: login }] },
    });
    // Ista poruka za nepostojeći nalog i pogrešnu lozinku.
    if (!user?.passwordHash || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Pogrešno korisničko ime ili lozinka.');
    }
    return this.session(user);
  }

  async forgotPassword(email: string) {
    const user = await this.prisma.user.findUnique({ where: { email: email.toLowerCase() } });
    if (user && !user.deletedAt && !user.isBlocked) {
      const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
      await this.prisma.passwordReset.create({
        data: {
          userId: user.id,
          codeHash: await bcrypt.hash(code, 10),
          expiresAt: new Date(Date.now() + 15 * 60_000),
        },
      });
      await this.mail.send(
        user.email!,
        '25 Slova — promena lozinke',
        `Vaš kod za promenu lozinke je: ${code}\nKod važi 15 minuta.`,
      );
    }
    // Uvek isti odgovor, da se ne bi otkrilo koji e-mail postoji.
    return { ok: true, message: 'Ako nalog postoji, poslali smo kod na e-mail.' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email.toLowerCase() } });
    const invalid = new BadRequestException('Kod nije ispravan ili je istekao.');
    if (!user) throw invalid;
    const resets = await this.prisma.passwordReset.findMany({
      where: { userId: user.id, usedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
      take: 3,
    });
    for (const r of resets) {
      if (await bcrypt.compare(dto.code, r.codeHash)) {
        await this.prisma.$transaction([
          this.prisma.passwordReset.updateMany({ where: { userId: user.id, usedAt: null }, data: { usedAt: new Date() } }),
          this.prisma.user.update({
            where: { id: user.id },
            data: { passwordHash: await bcrypt.hash(dto.newPassword, 12) },
          }),
        ]);
        return { ok: true };
      }
    }
    throw invalid;
  }

  /**
   * Prijava preko Google/Apple naloga.
   * - Ako je nalog već povezan → prijava.
   * - Ako ne postoji → vraća se socialToken; aplikacija traži da korisnik dopuni profil.
   * - Ako postoji drugi nalog sa istim e-mailom → NE povezujemo automatski
   *   (sprečava preuzimanje naloga); korisnik se prijavljuje lozinkom i povezuje iz profila.
   */
  async socialLogin(provider: SocialProvider, dto: SocialLoginDto) {
    const id = await this.social.verify(provider, dto.idToken);
    const field = provider === 'google' ? 'googleId' : 'appleId';
    const existing = await this.prisma.user.findFirst({ where: { [field]: id.subject, deletedAt: null } });
    if (existing) return { status: 'OK' as const, ...(await this.session(existing)) };

    if (id.email) {
      const sameEmail = await this.prisma.user.findUnique({ where: { email: id.email } });
      if (sameEmail && !sameEmail.deletedAt) {
        throw new ConflictException(
          'Nalog sa ovim e-mailom već postoji. Prijavite se lozinkom, pa povežite nalog u profilu.',
        );
      }
    }
    const socialToken = await this.jwt.signAsync(
      { kind: 'social', provider, sub: id.subject, email: id.emailVerified ? id.email : null },
      { expiresIn: '30m' },
    );
    return {
      status: 'NEEDS_PROFILE' as const,
      socialToken,
      suggested: { fullName: dto.fullName || id.name || '', email: id.email },
    };
  }

  async socialComplete(dto: SocialCompleteDto) {
    let payload: { kind: string; provider: SocialProvider; sub: string; email: string | null };
    try {
      payload = await this.jwt.verifyAsync(dto.socialToken);
    } catch {
      throw new UnauthorizedException('Sesija za registraciju je istekla. Pokušajte ponovo.');
    }
    if (payload.kind !== 'social') throw new UnauthorizedException();
    const birthDate = validateBirthDate(dto.birthDate);
    await this.users.assertUsernameFree(dto.username);
    if (payload.email) await this.users.assertEmailFree(payload.email);
    const field = payload.provider === 'google' ? 'googleId' : 'appleId';
    const user = await this.prisma.user.create({
      data: {
        username: dto.username,
        usernameLower: dto.username.toLowerCase(),
        fullName: dto.fullName,
        gender: dto.gender,
        birthDate,
        email: payload.email,
        phone: dto.phone || null,
        [field]: payload.sub,
      },
    });
    return this.session(user);
  }

  /** Povezivanje Google/Apple naloga sa već prijavljenim korisnikom. */
  async link(user: User, provider: SocialProvider, idToken: string) {
    const id: SocialIdentity = await this.social.verify(provider, idToken);
    const field = provider === 'google' ? 'googleId' : 'appleId';
    const other = await this.prisma.user.findFirst({ where: { [field]: id.subject } });
    if (other && other.id !== user.id) throw new ConflictException('Ovaj nalog je već povezan sa drugim korisnikom.');
    const updated = await this.prisma.user.update({ where: { id: user.id }, data: { [field]: id.subject } });
    return this.users.me(updated);
  }
}
