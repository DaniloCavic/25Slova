import { Controller, Get, Injectable, NotFoundException, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { User } from '@prisma/client';
import { CurrentUser } from '../common/auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { levelForCents, levelProgress, toPoints } from '../game/engine/rules';
import { PointsService } from './points.service';

/** Broj poslednjih partija koje se prikazuju na profilu. */
export const RECENT_MATCHES = 10;

/** Istorija partija — zajednička za „Moj profil“ i profile drugih igrača. */
@Injectable()
export class MatchHistoryService {
  constructor(private readonly prisma: PrismaService) {}

  async recent(userId: string, take = RECENT_MATCHES) {
    const rows = await this.prisma.matchPlayer.findMany({
      where: { userId, match: { status: 'FINISHED' } },
      orderBy: { createdAt: 'desc' },
      take,
      include: {
        match: {
          select: {
            mode: true,
            type: true,
            endReason: true,
            winnerId: true,
            isDraw: true,
            endedAt: true,
            players: { select: { userId: true, score: true, user: { select: { username: true } } } },
          },
        },
      },
    });
    return rows.map((r) => {
      const opp = r.match.players.find((p) => p.userId !== userId);
      return {
        matchId: r.matchId,
        mode: r.match.mode,
        initialLetters: r.initialLetters,
        endReason: r.match.endReason,
        outcome: r.match.isDraw ? 'DRAW' : r.match.winnerId === userId ? 'WIN' : 'LOSS',
        myScore: r.score,
        myWords: r.wordsCount,
        opponent: opp?.user.username ?? null,
        opponentScore: opp?.score ?? null,
        pointsDelta: toPoints(r.pointsDelta),
        endedAt: r.match.endedAt,
      };
    });
  }

  /**
   * Završena partija sa obe table i rečima, iz ugla jednog igrača
   * (isti oblik kao događaj „match:end“, da bi aplikacija koristila isti ekran).
   */
  async detail(matchId: string, viewerId: string, asUserId?: string) {
    const m = await this.prisma.match.findFirst({
      where: { id: matchId, status: 'FINISHED' },
      include: {
        players: {
          orderBy: { seat: 'asc' },
          include: { user: { select: { id: true, username: true, avatarUrl: true, totalPoints: true } } },
        },
      },
    });
    if (!m || m.players.length !== 2) throw new NotFoundException('Partija ne postoji.');
    const pick = (id?: string) => m.players.find((p) => p.userId === id);
    const me = pick(viewerId) ?? pick(asUserId) ?? m.players[0];
    const opp = m.players.find((p) => p !== me)!;
    const side = (p: (typeof m.players)[number]) => ({
      userId: p.userId,
      username: p.user.username,
      avatarUrl: p.user.avatarUrl,
      level: levelForCents(p.user.totalPoints),
      board: p.board ?? [],
      lives: p.livesLeft,
      points: p.score,
      wordsCount: p.wordsCount,
      lines: p.words ?? [],
    });
    const initial = (m.initialCells as { cell: number }[] | null) ?? [];
    return {
      matchId: m.id,
      mode: m.mode,
      initialLetters: initial.length,
      viewerIsPlayer: me.userId === viewerId,
      outcome: m.isDraw ? 'DRAW' : m.winnerId === me.userId ? 'WIN' : 'LOSS',
      endReason: m.endReason,
      pointsDelta: toPoints(me.pointsDelta),
      endedAt: m.endedAt,
      initialCells: initial.map((c) => c.cell),
      me: side(me),
      opponent: side(opp),
    };
  }
}

@Controller('matches')
export class MatchesController {
  constructor(private readonly history: MatchHistoryService) {}

  /** Poslednjih 10 odigranih partija korisnika. */
  @Get('recent')
  recent(@CurrentUser() user: User) {
    return this.history.recent(user.id);
  }

  /** Detalji završene partije (obe table i reči). `as` = iz čijeg ugla (za profile drugih igrača). */
  @Get(':id')
  detail(
    @CurrentUser() user: User,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Query('as') as?: string,
  ) {
    return this.history.detail(id, user.id, as);
  }
}

/** Javni profil igrača — ono što drugi vide (bez e-maila, telefona i tokena). */
@Controller('players')
export class PlayersController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly points: PointsService,
    private readonly history: MatchHistoryService,
  ) {}

  @Get(':id')
  async profile(@Param('id', new ParseUUIDPipe()) id: string) {
    const u = await this.prisma.user.findFirst({ where: { id, deletedAt: null } });
    if (!u) throw new NotFoundException('Igrač ne postoji.');
    const [period, medals, stats, recent] = await Promise.all([
      this.points.periodPoints(u.id),
      this.prisma.medal.findMany({
        where: { userId: u.id },
        orderBy: [{ createdAt: 'desc' }, { place: 'asc' }],
        select: { id: true, period: true, periodKey: true, place: true, points: true },
      }),
      this.stats(u.id),
      this.history.recent(u.id),
    ]);
    return {
      id: u.id,
      username: u.username,
      avatarUrl: u.avatarUrl,
      level: levelForCents(u.totalPoints),
      levelProgress: levelProgress(toPoints(u.totalPoints)),
      totalPoints: toPoints(u.totalPoints),
      ...period,
      memberSince: u.createdAt,
      stats,
      medals: medals.map((m) => ({ ...m, points: toPoints(m.points) })),
      recent,
    };
  }

  private async stats(userId: string) {
    const where = { userId, match: { status: 'FINISHED' as const } };
    const [played, wins, draws] = await Promise.all([
      this.prisma.matchPlayer.count({ where }),
      this.prisma.match.count({ where: { status: 'FINISHED', winnerId: userId } }),
      this.prisma.matchPlayer.count({ where: { userId, match: { status: 'FINISHED', isDraw: true } } }),
    ]);
    return { played, wins, draws, losses: played - wins - draws };
  }
}
