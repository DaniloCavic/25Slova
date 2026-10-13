import { BadRequestException, Body, Controller, Delete, Get, NotFoundException, Param, Patch, Post, Put, Query } from '@nestjs/common';
import { Prisma, Role, User } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsNumber, IsOptional, IsString, Matches, MaxLength, Min } from 'class-validator';
import * as bcrypt from 'bcryptjs';
import { AdminOnly, CurrentUser } from '../common/auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService, validateBirthDate } from '../users/users.service';
import { PASSWORD_REGEX, ProfileFields, UpdateProfileDto } from '../users/dto';
import { TokensService } from '../tokens/tokens.service';
import { PointsService } from '../users/points.service';
import { GameService } from '../game/game.service';
import { SettingsService, MatchmakingSettings } from '../settings/settings.service';
import { DictionaryService } from '../words/dictionary.service';
import { dayKey, monthKey } from '../common/time';
import { levelForCents, toCents, toPoints } from '../game/engine/rules';
import { IsEmail } from 'class-validator';
import { Transform } from 'class-transformer';

class AdminCreateUserDto extends ProfileFields {
  @Transform(({ value }) => (typeof value === 'string' && value.trim() ? value.trim() : undefined))
  @IsOptional()
  @IsEmail({}, { message: 'E-mail nije ispravan.' })
  email?: string;

  @Matches(PASSWORD_REGEX, { message: 'Lozinka mora imati najmanje 8 znakova, bar jedno slovo i bar jedan broj.' })
  password: string;

  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  tokens?: number;
}

class AdminUpdateUserDto extends UpdateProfileDto {
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @IsOptional()
  @Matches(PASSWORD_REGEX, { message: 'Lozinka mora imati najmanje 8 znakova, bar jedno slovo i bar jedan broj.' })
  password?: string;
}

class BlockDto {
  @IsOptional()
  @IsString()
  @MaxLength(300)
  reason?: string;
}

class AdjustDto {
  @Type(() => Number)
  @IsInt()
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

/** Poeni mogu imati dve decimale (npr. 12,50). */
class AdjustPointsDto {
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 }, { message: 'Poeni mogu imati najviše dve decimale.' })
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

class MatchmakingDto implements Partial<MatchmakingSettings> {
  @IsOptional() @IsNumber() initialLevelRange?: number;
  @IsOptional() @IsNumber() expandEverySeconds?: number;
  @IsOptional() @IsNumber() maxLevelRange?: number;
  @IsOptional() @IsNumber() privateCodeMinutes?: number;
}

@AdminOnly()
@Controller('admin')
export class AdminController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly tokens: TokensService,
    private readonly points: PointsService,
    private readonly game: GameService,
    private readonly settings: SettingsService,
    private readonly dict: DictionaryService,
  ) {}

  private adminView(u: User) {
    return {
      id: u.id,
      username: u.username,
      fullName: u.fullName,
      gender: u.gender,
      birthDate: u.birthDate ? u.birthDate.toISOString().slice(0, 10) : null,
      email: u.email,
      phone: u.phone,
      avatarUrl: u.avatarUrl,
      role: u.role,
      isBlocked: u.isBlocked,
      blockedReason: u.blockedReason,
      blockedAt: u.blockedAt,
      tokens: u.tokens,
      totalPoints: toPoints(u.totalPoints),
      level: levelForCents(u.totalPoints),
      linkedGoogle: !!u.googleId,
      linkedApple: !!u.appleId,
      lastSeenAt: u.lastSeenAt,
      deletedAt: u.deletedAt,
      createdAt: u.createdAt,
    };
  }

  private async getUser(id: string) {
    const u = await this.prisma.user.findUnique({ where: { id } });
    if (!u) throw new NotFoundException('Korisnik ne postoji.');
    return u;
  }

  // ------------------------------------------------------------ korisnici

  @Get('users')
  async list(
    @Query('search') search?: string,
    @Query('status') status?: 'active' | 'blocked' | 'deleted' | 'all',
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '25',
  ) {
    const where: Prisma.UserWhereInput = {};
    if (status === 'blocked') Object.assign(where, { isBlocked: true, deletedAt: null });
    else if (status === 'deleted') where.deletedAt = { not: null };
    else if (status !== 'all') where.deletedAt = null;
    if (search) {
      where.OR = [
        { username: { contains: search, mode: 'insensitive' } },
        { fullName: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search } },
      ];
    }
    const p = Math.max(1, Number(page) || 1);
    const ps = Math.min(100, Math.max(1, Number(pageSize) || 25));
    const [total, rows] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({ where, orderBy: { createdAt: 'desc' }, skip: (p - 1) * ps, take: ps }),
    ]);
    return { total, page: p, pageSize: ps, items: rows.map((u) => this.adminView(u)) };
  }

  @Get('users/:id')
  async detail(@Param('id') id: string) {
    const u = await this.getUser(id);
    const [period, tokenHistory, matches, medals] = await Promise.all([
      this.points.periodPoints(id),
      this.tokens.history(id, 30),
      this.prisma.matchPlayer.findMany({
        where: { userId: id },
        orderBy: { createdAt: 'desc' },
        take: 20,
        include: { match: { select: { mode: true, type: true, status: true, endReason: true, winnerId: true, isDraw: true, endedAt: true } } },
      }),
      this.users.medals(id),
    ]);
    return {
      user: { ...this.adminView(u), ...period },
      tokenHistory,
      medals,
      matches: matches.map((m) => ({
        matchId: m.matchId,
        mode: m.match.mode,
        status: m.match.status,
        endReason: m.match.endReason,
        outcome: m.match.isDraw ? 'DRAW' : m.match.winnerId ? (m.match.winnerId === id ? 'WIN' : 'LOSS') : null,
        score: m.score,
        wordsCount: m.wordsCount,
        pointsDelta: toPoints(m.pointsDelta),
        endedAt: m.match.endedAt,
      })),
    };
  }

  @Post('users')
  async create(@Body() dto: AdminCreateUserDto) {
    await this.users.assertUsernameFree(dto.username);
    if (dto.email) await this.users.assertEmailFree(dto.email);
    const u = await this.prisma.user.create({
      data: {
        username: dto.username,
        usernameLower: dto.username.toLowerCase(),
        fullName: dto.fullName,
        gender: dto.gender,
        birthDate: validateBirthDate(dto.birthDate),
        email: dto.email?.toLowerCase() ?? null,
        phone: dto.phone || null,
        passwordHash: await bcrypt.hash(dto.password, 12),
        role: dto.role ?? 'USER',
      },
    });
    if (dto.tokens) await this.tokens.change(u.id, dto.tokens, 'ADMIN_ADJUST', { note: 'Početni tokeni (admin)' });
    return this.adminView(await this.getUser(u.id));
  }

  @Patch('users/:id')
  async update(@Param('id') id: string, @Body() dto: AdminUpdateUserDto, @CurrentUser() admin: User) {
    const u = await this.getUser(id);
    if (u.deletedAt) throw new BadRequestException('Nalog je obrisan.');
    const data = await this.users.buildProfileUpdate(id, dto);
    if (dto.role) {
      if (id === admin.id && dto.role !== 'ADMIN') throw new BadRequestException('Ne možete sebi ukloniti admin prava.');
      data.role = dto.role;
    }
    if (dto.password) data.passwordHash = await bcrypt.hash(dto.password, 12);
    return this.adminView(await this.prisma.user.update({ where: { id }, data }));
  }

  @Post('users/:id/block')
  async block(@Param('id') id: string, @Body() dto: BlockDto, @CurrentUser() admin: User) {
    if (id === admin.id) throw new BadRequestException('Ne možete blokirati sebe.');
    await this.getUser(id);
    const u = await this.prisma.user.update({
      where: { id },
      data: { isBlocked: true, blockedReason: dto.reason || null, blockedAt: new Date() },
    });
    await this.game.kick(id, dto.reason || 'Nalog je blokiran.');
    return this.adminView(u);
  }

  @Post('users/:id/unblock')
  async unblock(@Param('id') id: string) {
    await this.getUser(id);
    return this.adminView(
      await this.prisma.user.update({ where: { id }, data: { isBlocked: false, blockedReason: null, blockedAt: null } }),
    );
  }

  @Post('users/:id/tokens')
  async adjustTokens(@Param('id') id: string, @Body() dto: AdjustDto, @CurrentUser() admin: User) {
    await this.getUser(id);
    if (!dto.amount) throw new BadRequestException('Iznos ne može biti 0.');
    await this.tokens.change(id, dto.amount, 'ADMIN_ADJUST', { note: dto.note || `Admin: ${admin.username}` });
    return this.adminView(await this.getUser(id));
  }

  @Post('users/:id/points')
  async adjustPoints(@Param('id') id: string, @Body() dto: AdjustPointsDto) {
    await this.getUser(id);
    if (!dto.amount) throw new BadRequestException('Iznos ne može biti 0.');
    await this.prisma.$transaction((tx) => this.points.apply(tx, id, toCents(dto.amount), 'ADMIN_ADJUST'));
    return this.adminView(await this.getUser(id));
  }

  @Delete('users/:id')
  async remove(@Param('id') id: string, @CurrentUser() admin: User) {
    if (id === admin.id) throw new BadRequestException('Ne možete obrisati sopstveni nalog odavde.');
    await this.getUser(id);
    await this.game.kick(id, 'Nalog je obrisan.');
    return this.users.deleteAccount(id);
  }

  // ------------------------------------------------------------ pregled

  @Get('stats')
  async stats() {
    const today = new Date(`${dayKey()}T00:00:00`);
    const [users, blocked, newToday, activeToday, matchesToday, matchesTotal, words, tokenSums] = await Promise.all([
      this.prisma.user.count({ where: { deletedAt: null } }),
      this.prisma.user.count({ where: { isBlocked: true, deletedAt: null } }),
      this.prisma.user.count({ where: { createdAt: { gte: today } } }),
      this.prisma.user.count({ where: { lastDailyRewardDay: dayKey() } }),
      this.prisma.match.count({ where: { status: 'FINISHED', endedAt: { gte: today } } }),
      this.prisma.match.count({ where: { status: 'FINISHED' } }),
      this.prisma.word.count(),
      this.prisma.tokenTransaction.groupBy({
        by: ['type'],
        _sum: { amount: true },
        _count: true,
        where: { createdAt: { gte: new Date(`${monthKey()}-01T00:00:00`) } },
      }),
    ]);
    return {
      users,
      blocked,
      newToday,
      activeToday,
      matchesToday,
      matchesTotal,
      words,
      dictionaryLoaded: this.dict.size,
      live: this.game.stats(),
      tokensThisMonth: tokenSums.map((t) => ({ type: t.type, count: t._count, amount: t._sum.amount ?? 0 })),
    };
  }

  @Get('settings/matchmaking')
  getMatchmaking() {
    return this.settings.matchmaking;
  }

  @Put('settings/matchmaking')
  setMatchmaking(@Body() dto: MatchmakingDto) {
    return this.settings.updateMatchmaking(dto);
  }
}
