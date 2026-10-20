import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { promises as fs } from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { selfView } from '../common/public-user';
import { toPoints } from '../game/engine/rules';
import { PointsService } from './points.service';
import { ChangePasswordDto, UpdateProfileDto } from './dto';

export const UPLOAD_DIR = path.resolve(process.env.UPLOAD_DIR || 'uploads');

export function validateBirthDate(value: string): Date {
  const d = new Date(`${value}T00:00:00Z`);
  const now = new Date();
  if (Number.isNaN(d.getTime()) || d > now || d.getUTCFullYear() < 1900) {
    throw new BadRequestException('Datum rođenja nije ispravan.');
  }
  return d;
}

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly points: PointsService,
  ) {}

  async me(user: User) {
    return selfView(user, await this.points.periodPoints(user.id));
  }

  async assertUsernameFree(username: string, exceptUserId?: string) {
    const existing = await this.prisma.user.findUnique({ where: { usernameLower: username.toLowerCase() } });
    if (existing && existing.id !== exceptUserId) throw new ConflictException('Korisničko ime je zauzeto.');
  }

  async assertEmailFree(email: string, exceptUserId?: string) {
    const existing = await this.prisma.user.findUnique({ where: { email: email.toLowerCase() } });
    if (existing && existing.id !== exceptUserId) throw new ConflictException('E-mail je već u upotrebi.');
  }

  /** Zajednička obrada izmene profila — koristi je i korisnik i administrator. */
  async buildProfileUpdate(userId: string, dto: UpdateProfileDto): Promise<Prisma.UserUpdateInput> {
    const data: Prisma.UserUpdateInput = {};
    if (dto.username !== undefined) {
      await this.assertUsernameFree(dto.username, userId);
      data.username = dto.username;
      data.usernameLower = dto.username.toLowerCase();
    }
    if (dto.email !== undefined) {
      await this.assertEmailFree(dto.email, userId);
      data.email = dto.email.toLowerCase();
    }
    if (dto.fullName !== undefined) data.fullName = dto.fullName;
    if (dto.gender !== undefined) data.gender = dto.gender;
    if (dto.birthDate !== undefined) data.birthDate = validateBirthDate(dto.birthDate);
    if (dto.phone !== undefined) data.phone = dto.phone || null;
    return data;
  }

  async updateMe(user: User, dto: UpdateProfileDto) {
    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: await this.buildProfileUpdate(user.id, dto),
    });
    return this.me(updated);
  }

  async changePassword(user: User, dto: ChangePasswordDto) {
    if (user.passwordHash) {
      if (!dto.currentPassword || !(await bcrypt.compare(dto.currentPassword, user.passwordHash))) {
        throw new UnauthorizedException('Trenutna lozinka nije tačna.');
      }
    }
    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: await bcrypt.hash(dto.newPassword, 12) },
    });
    return { ok: true };
  }

  async setAvatar(user: User, dataUrl: string) {
    const [, mime, b64] = /^data:image\/(png|jpeg);base64,(.+)$/.exec(dataUrl) ?? [];
    if (!b64) throw new BadRequestException('Neispravan format slike.');
    const buf = Buffer.from(b64, 'base64');
    if (buf.length > 300 * 1024) throw new BadRequestException('Slika je prevelika (najviše 300 KB).');
    const dir = path.join(UPLOAD_DIR, 'avatars');
    await fs.mkdir(dir, { recursive: true });
    const name = `${user.id}-${randomUUID().slice(0, 8)}.${mime === 'png' ? 'png' : 'jpg'}`;
    await fs.writeFile(path.join(dir, name), buf);
    await this.removeAvatarFile(user.avatarUrl);
    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: { avatarUrl: `/uploads/avatars/${name}` },
    });
    return this.me(updated);
  }

  async removeAvatar(user: User) {
    await this.removeAvatarFile(user.avatarUrl);
    const updated = await this.prisma.user.update({ where: { id: user.id }, data: { avatarUrl: null } });
    return this.me(updated);
  }

  private async removeAvatarFile(url: string | null) {
    if (!url?.startsWith('/uploads/avatars/')) return;
    await fs.rm(path.join(UPLOAD_DIR, 'avatars', path.basename(url)), { force: true });
  }

  /**
   * Brisanje naloga: lični podaci se trajno uklanjaju, a istorija partija ostaje
   * anonimizovana da protivnicima ne bi nestale odigrane partije.
   */
  async deleteAccount(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    await this.removeAvatarFile(user.avatarUrl);
    const anon = `obrisan_${userId.slice(0, 8)}`;
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        username: anon,
        usernameLower: anon,
        fullName: 'Obrisan nalog',
        email: null,
        phone: null,
        gender: null,
        birthDate: null,
        passwordHash: null,
        googleId: null,
        appleId: null,
        avatarUrl: null,
        deletedAt: new Date(),
      },
    });
    return { ok: true };
  }

  async medals(userId: string) {
    const rows = await this.prisma.medal.findMany({
      where: { userId },
      orderBy: [{ createdAt: 'desc' }, { place: 'asc' }],
      select: { id: true, period: true, periodKey: true, place: true, points: true },
    });
    return rows.map((m) => ({ ...m, points: toPoints(m.points) }));
  }

  /** Medalje o kojima igrač još nije obavešten u aplikaciji (prikazuju se preko ekrana). */
  async unseenMedals(userId: string) {
    const rows = await this.prisma.medal.findMany({
      where: { userId, seenAt: null },
      orderBy: [{ createdAt: 'asc' }, { place: 'asc' }],
      select: { id: true, period: true, periodKey: true, place: true, points: true },
    });
    return rows.map((m) => ({ ...m, points: toPoints(m.points) }));
  }

  async markMedalsSeen(userId: string, ids: string[]) {
    await this.prisma.medal.updateMany({ where: { userId, id: { in: ids }, seenAt: null }, data: { seenAt: new Date() } });
    return { ok: true };
  }
}
