import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { MedalPeriod, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { GAME_TZ, monthKey, previousMonthKey, previousYearKey, yearKey } from '../common/time';
import { levelForPoints } from '../game/engine/rules';

export type Period = 'month' | 'year' | 'total';

interface Row {
  userId: string;
  username: string;
  avatarUrl: string | null;
  totalPoints: number;
  points: number;
  rank: number;
}

@Injectable()
export class LeaderboardService implements OnApplicationBootstrap {
  private readonly log = new Logger(LeaderboardService.name);
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Rang-lista. Mesečna/godišnja se računa iz istorije poena za traženi period,
   * pa su rezultati prethodnih perioda uvek dostupni (key = "2026-09" ili "2026").
   * Pri istom broju poena ispred je onaj ko je do njih stigao ranije.
   */
  private async rows(
    period: Period,
    key: string | null,
    limit: number,
    onlyUserId?: string,
    search?: string,
  ): Promise<Row[]> {
    // Mesto se računa na celoj listi, a tek onda se filtrira — pretraga pokazuje pravo mesto igrača.
    const pattern = search ? `%${search.replace(/[\\%_]/g, (c) => `\\${c}`)}%` : null;
    const userFilter = Prisma.sql`${onlyUserId ? Prisma.sql`AND r."userId" = ${onlyUserId}` : Prisma.empty} ${
      pattern ? Prisma.sql`AND r.username ILIKE ${pattern}` : Prisma.empty
    }`;
    if (period === 'total') {
      return this.prisma.$queryRaw<Row[]>`
        SELECT * FROM (
          SELECT u.id AS "userId", u.username, u."avatarUrl", u."totalPoints", u."totalPoints" AS points,
                 ROW_NUMBER() OVER (ORDER BY u."totalPoints" DESC, u."createdAt" ASC)::int AS rank
          FROM "User" u
          WHERE u."deletedAt" IS NULL AND u."isBlocked" = false AND u.role = 'USER'
        ) r WHERE true ${userFilter} ORDER BY rank LIMIT ${limit}`;
    }
    const col = period === 'month' ? Prisma.sql`"monthKey"` : Prisma.sql`"yearKey"`;
    return this.prisma.$queryRaw<Row[]>`
      SELECT * FROM (
        SELECT u.id AS "userId", u.username, u."avatarUrl", u."totalPoints", s.points::int AS points,
               ROW_NUMBER() OVER (ORDER BY s.points DESC, s.last_at ASC)::int AS rank
        FROM (
          SELECT "userId", SUM(delta) AS points, MAX("createdAt") AS last_at
          FROM "PointsEvent" WHERE ${col} = ${key} GROUP BY "userId"
        ) s
        JOIN "User" u ON u.id = s."userId"
        WHERE u."deletedAt" IS NULL AND u."isBlocked" = false AND u.role = 'USER'
      ) r WHERE true ${userFilter} ORDER BY rank LIMIT ${limit}`;
  }

  async leaderboard(period: Period, key: string | undefined, userId?: string, search?: string) {
    const k = period === 'total' ? null : key || (period === 'month' ? monthKey() : yearKey());
    const q = search?.trim().slice(0, 30) || undefined;
    const top = await this.rows(period, k, q ? 50 : 100, undefined, q);
    const mine = userId ? (await this.rows(period, k, 1, userId))[0] ?? null : null;
    const view = (r: Row) => ({
      rank: r.rank,
      userId: r.userId,
      username: r.username,
      avatarUrl: r.avatarUrl,
      level: levelForPoints(r.totalPoints),
      points: r.points,
    });
    return { period, key: k, search: q ?? null, items: top.map(view), me: mine ? view(mine) : null };
  }

  /** Medalje za prva tri mesta. Idempotentno — za već nagrađen period ne radi ništa. */
  async awardMedals(period: MedalPeriod, key: string) {
    const exists = await this.prisma.medal.count({ where: { period, periodKey: key } });
    if (exists) return 0;
    const top = (await this.rows(period === 'MONTH' ? 'month' : 'year', key, 3)).filter((r) => r.points > 0);
    if (!top.length) return 0;
    await this.prisma.medal.createMany({
      data: top.map((r) => ({ userId: r.userId, period, periodKey: key, place: r.rank, points: r.points })),
      skipDuplicates: true,
    });
    this.log.log(`Dodeljene medalje za ${period} ${key}: ${top.map((r) => r.username).join(', ')}`);
    return top.length;
  }

  /** Prvog u mesecu u 00:05 (vreme igre): medalje za prošli mesec, a 1. januara i za prošlu godinu. */
  @Cron('5 0 1 * *', { timeZone: GAME_TZ })
  async closePeriods() {
    await this.awardMedals('MONTH', previousMonthKey());
    if (monthKey().endsWith('-01')) await this.awardMedals('YEAR', previousYearKey());
  }

  /** Ako je server bio ugašen u trenutku zatvaranja perioda — nadoknadi pri pokretanju. */
  async onApplicationBootstrap() {
    await this.awardMedals('MONTH', previousMonthKey()).catch((e) => this.log.error(e));
    await this.awardMedals('YEAR', previousYearKey()).catch((e) => this.log.error(e));
  }

  /** "Najbolja tabla ikad" — ukupno i posebno za 1, 3 i 5 početnih slova. */
  async bestBoards() {
    const pick = (initialLetters?: number) =>
      this.prisma.matchPlayer.findFirst({
        where: {
          match: { status: 'FINISHED', endReason: 'BOARDS_FULL' },
          ...(initialLetters ? { initialLetters } : {}),
        },
        orderBy: [{ score: 'desc' }, { wordsCount: 'desc' }, { createdAt: 'asc' }],
        include: {
          user: { select: { username: true, avatarUrl: true, totalPoints: true } },
          match: { select: { initialCells: true, endedAt: true, type: true } },
        },
      });
    const [overall, t1, t3, t5] = await Promise.all([pick(), pick(1), pick(3), pick(5)]);
    const view = (r: Awaited<ReturnType<typeof pick>>) =>
      r && {
        username: r.user.username,
        avatarUrl: r.user.avatarUrl,
        level: levelForPoints(r.user.totalPoints),
        board: r.board,
        points: r.score,
        wordsCount: r.wordsCount,
        words: r.words,
        initialLetters: r.initialLetters,
        initialCells: ((r.match.initialCells as { cell: number }[] | null) ?? []).map((c) => c.cell),
        achievedAt: r.match.endedAt,
      };
    return { overall: view(overall), byInitialLetters: { 1: view(t1), 3: view(t3), 5: view(t5) } };
  }
}
