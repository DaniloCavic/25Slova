import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { MedalPeriod, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../push/push.service';
import { GAME_TZ, monthKey, previousMonthKey, previousWeekKey, previousYearKey, weekKey, yearKey } from '../common/time';
import { levelForCents, toPoints } from '../game/engine/rules';

export type Period = 'week' | 'month' | 'year' | 'total';

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
  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
  ) {}

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
    const col =
      period === 'week' ? Prisma.sql`"weekKey"` : period === 'month' ? Prisma.sql`"monthKey"` : Prisma.sql`"yearKey"`;
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
    const current = { week: weekKey, month: monthKey, year: yearKey } as const;
    const k = period === 'total' ? null : key || current[period]();
    const q = search?.trim().slice(0, 30) || undefined;
    const top = await this.rows(period, k, q ? 50 : 100, undefined, q);
    const mine = userId ? (await this.rows(period, k, 1, userId))[0] ?? null : null;
    const view = (r: Row) => ({
      rank: r.rank,
      userId: r.userId,
      username: r.username,
      avatarUrl: r.avatarUrl,
      level: levelForCents(r.totalPoints),
      points: toPoints(r.points),
    });
    return { period, key: k, search: q ?? null, items: top.map(view), me: mine ? view(mine) : null };
  }

  /** Medalje za prva tri mesta. Idempotentno — za već nagrađen period ne radi ništa. */
  async awardMedals(period: MedalPeriod, key: string) {
    const exists = await this.prisma.medal.count({ where: { period, periodKey: key } });
    if (exists) return 0;
    const p: Period = period === 'WEEK' ? 'week' : period === 'MONTH' ? 'month' : 'year';
    const top = (await this.rows(p, key, 3)).filter((r) => r.points > 0);
    if (!top.length) return 0;
    await this.prisma.medal.createMany({
      data: top.map((r) => ({ userId: r.userId, period, periodKey: key, place: r.rank, points: r.points })),
      skipDuplicates: true,
    });
    this.log.log(`Dodeljene medalje za ${period} ${key}: ${top.map((r) => r.username).join(', ')}`);
    const medal = ['zlatnu', 'srebrnu', 'bronzanu'];
    const list = { WEEK: 'nedeljnoj', MONTH: 'mesečnoj', YEAR: 'godišnjoj' }[period];
    for (const r of top) {
      void this.push.send(r.userId, {
        title: `Osvojena medalja! ${['🥇', '🥈', '🥉'][r.rank - 1] ?? '🏅'}`,
        body: `Čestitamo! ${r.rank}. mesto na ${list} rang listi (${medalPeriodText(period, key)}) — dobijaš ${medal[r.rank - 1]} medalju.`,
        tag: `medal-${period}-${key}`,
      });
    }
    return top.length;
  }

  /** Svakog ponedeljka u 00:05 (vreme igre): medalje za prošlu nedelju. */
  @Cron('5 0 * * 1', { timeZone: GAME_TZ })
  async closeWeek() {
    await this.awardMedals('WEEK', previousWeekKey());
  }

  /** Prvog u mesecu u 00:05 (vreme igre): medalje za prošli mesec, a 1. januara i za prošlu godinu. */
  @Cron('5 0 1 * *', { timeZone: GAME_TZ })
  async closePeriods() {
    await this.awardMedals('MONTH', previousMonthKey());
    if (monthKey().endsWith('-01')) await this.awardMedals('YEAR', previousYearKey());
  }

  /** Ako je server bio ugašen u trenutku zatvaranja perioda — nadoknadi pri pokretanju. */
  async onApplicationBootstrap() {
    await this.awardMedals('WEEK', previousWeekKey()).catch((e) => this.log.error(e));
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
        level: levelForCents(r.user.totalPoints),
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

const MONTHS = ['januar', 'februar', 'mart', 'april', 'maj', 'jun', 'jul', 'avgust', 'septembar', 'oktobar', 'novembar', 'decembar'];

/** "2026-W42" → "nedelja 42", "2026-10" → "oktobar 2026.", "2026" → "2026. godina" */
function medalPeriodText(period: MedalPeriod, key: string) {
  if (period === 'WEEK') return `nedelja ${Number(key.split('-W')[1])}`;
  if (period === 'MONTH') {
    const [y, m] = key.split('-');
    return `${MONTHS[Number(m) - 1]} ${y}.`;
  }
  return `${key}. godina`;
}
