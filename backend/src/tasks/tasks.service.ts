import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { createHash } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { TokensService } from '../tokens/tokens.service';
import { DictionaryService } from '../words/dictionary.service';
import { dayKey, monthKey, weekKey } from '../common/time';
import { letterCount, toLatin } from '../game/engine/alphabet';
import { LINES } from '../game/engine/scoring';
import { toPoints } from '../game/engine/rules';

export type Period = 'day' | 'week' | 'month';

/** Jedna završena partija iz ugla igrača (sve što zadaci koriste). */
interface Played {
  endedAt: Date;
  day: string;
  week: string;
  month: string;
  win: boolean;
  noLifeLost: boolean;
  words: number;
  board: (string | null)[];
}

interface TaskDef {
  id: string;
  title: string;
  target: number;
  reward: number;
  /** Napredak iz partija perioda (i dodatnih podataka) */
  progress: (c: Ctx) => number;
}

interface Ctx {
  games: Played[];
  /** Poeni na rang listi za period (cele vrednosti, posle decimala se ne gleda) */
  points: number;
  /** Za mesečne: koliko je dana / nedelja ispunilo sve zadatke */
  allDailyDays?: number;
  allWeeklyWeeks?: number;
  challenge?: string[];
}

const wins = (g: Played[]) => g.filter((x) => x.win).length;
function bestStreak(g: Played[]) {
  let best = 0;
  let cur = 0;
  for (const x of [...g].sort((a, b) => a.endedAt.getTime() - b.endedAt.getTime())) {
    cur = x.win ? cur + 1 : 0;
    best = Math.max(best, cur);
  }
  return best;
}
const byDay = (g: Played[]) => {
  const m = new Map<string, Played[]>();
  for (const x of g) m.set(x.day, [...(m.get(x.day) ?? []), x]);
  return m;
};

/** Koliko od reči izazova se nalazi na tabli (u bilo kom redu, koloni ili dijagonali, u oba smera). */
export function challengeHits(board: (string | null)[], words: string[]) {
  const lines = LINES.flatMap((l) => {
    const s = l.cells.map((i) => board[i] ?? '·').join('');
    return [s, [...s].reverse().join('')];
  });
  return words.map((w) => lines.some((s) => s.includes(w)));
}

const DAILY: TaskDef[] = [
  { id: 'd_play5', title: 'Odigraj 5 partija', target: 5, reward: 10, progress: (c) => c.games.length },
  { id: 'd_win3', title: 'Pobedi u 3 partije', target: 3, reward: 10, progress: (c) => wins(c.games) },
  { id: 'd_streak3', title: 'Pobedi 3 partije zaredom', target: 3, reward: 30, progress: (c) => bestStreak(c.games) },
  { id: 'd_win10', title: 'Pobedi u 10 partija', target: 10, reward: 100, progress: (c) => wins(c.games) },
  { id: 'd_streak10', title: 'Pobedi 10 partija zaredom', target: 10, reward: 200, progress: (c) => bestStreak(c.games) },
];
/** Glavni dnevni zadatak: sve 4 reči na jednoj tabli u jednoj partiji. */
const MAIN: TaskDef = {
  id: 'd_main',
  title: 'Složi sve 4 reči na jednoj tabli',
  target: 4,
  reward: 50,
  progress: (c) =>
    Math.max(0, ...c.games.map((g) => challengeHits(g.board, c.challenge ?? []).filter(Boolean).length)),
};
const WEEKLY: TaskDef[] = [
  {
    id: 'w_play5x7',
    title: 'Svaki dan u nedelji odigraj 5 partija',
    target: 7,
    reward: 50,
    progress: (c) => [...byDay(c.games).values()].filter((g) => g.length >= 5).length,
  },
  {
    id: 'w_win3x7',
    title: 'Svaki dan u nedelji pobedi u 3 partije',
    target: 7,
    reward: 50,
    progress: (c) => [...byDay(c.games).values()].filter((g) => wins(g) >= 3).length,
  },
  { id: 'w_pts500', title: 'Osvoji 500 poena na nedeljnoj rang listi', target: 500, reward: 50, progress: (c) => c.points },
  { id: 'w_pts1000', title: 'Osvoji 1.000 poena na nedeljnoj rang listi', target: 1000, reward: 150, progress: (c) => c.points },
  {
    id: 'w_clean25',
    title: 'Pobedi 25 puta bez izgubljenog života',
    target: 25,
    reward: 50,
    progress: (c) => c.games.filter((g) => g.win && g.noLifeLost).length,
  },
  {
    id: 'w_words500',
    title: 'Sastavi 500 reči',
    target: 500,
    reward: 100,
    progress: (c) => c.games.reduce((s, g) => s + g.words, 0),
  },
];
const MONTHLY: TaskDef[] = [
  { id: 'm_days20', title: 'Igraj 20 različitih dana', target: 20, reward: 20, progress: (c) => byDay(c.games).size },
  { id: 'm_win100', title: 'Pobedi u 100 partija', target: 100, reward: 50, progress: (c) => wins(c.games) },
  { id: 'm_win300', title: 'Pobedi u 300 partija', target: 300, reward: 200, progress: (c) => wins(c.games) },
  { id: 'm_pts5000', title: 'Osvoji 5.000 poena na mesečnoj rang listi', target: 5000, reward: 100, progress: (c) => c.points },
  { id: 'm_pts10000', title: 'Osvoji 10.000 poena na mesečnoj rang listi', target: 10000, reward: 500, progress: (c) => c.points },
  { id: 'm_alldaily', title: 'Jednog dana ispuni sve dnevne zadatke', target: 1, reward: 100, progress: (c) => c.allDailyDays ?? 0 },
  { id: 'm_allweekly', title: 'Jedne nedelje ispuni sve nedeljne zadatke', target: 1, reward: 1000, progress: (c) => c.allWeeklyWeeks ?? 0 },
  { id: 'm_words1000', title: 'Sastavi 1.000 reči', target: 1000, reward: 100, progress: (c) => c.games.reduce((s, g) => s + g.words, 0) },
  { id: 'm_words3000', title: 'Sastavi 3.000 reči', target: 3000, reward: 500, progress: (c) => c.games.reduce((s, g) => s + g.words, 0) },
];

/** Retka slova se ne daju u reči izazova, da bi zadatak bio izvodljiv. */
const RARE = /[ЂЏФХЉЊЋЦ]/;

/**
 * Zadaci (dnevni, nedeljni, mesečni). Napredak se računa iz odigranih partija,
 * pa ne može da se „izgubi“ ni pokvari; nagrada se preuzima jednom (jedinstvena
 * referenca transakcije tokena).
 */
@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokensService,
    private readonly dict: DictionaryService,
  ) {}

  // -------------------------------------------------------------- izazov

  /** Reči glavnog dnevnog zadatka: svaki igrač svoje, svaki dan nove (2 × 5 slova, 2 × 4 slova). */
  async challenge(userId: string, day = dayKey()) {
    const row = await this.prisma.dailyChallenge.findUnique({ where: { userId_dayKey: { userId, dayKey: day } } });
    if (row) return row.words as string[];
    const words = this.pickWords(`${userId}:${day}`);
    await this.prisma.dailyChallenge
      .create({ data: { userId, dayKey: day, words: words as unknown as Prisma.InputJsonValue } })
      .catch(() => undefined);
    return words;
  }

  private pickWords(seed: string) {
    let h = createHash('sha256').update(seed).digest();
    let i = 0;
    const rand = () => {
      if (i + 4 > h.length) {
        h = createHash('sha256').update(h).digest();
        i = 0;
      }
      const v = h.readUInt32BE(i) / 0x1_0000_0000;
      i += 4;
      return v;
    };
    const pool = (n: number) => this.dict.allWords().filter((w) => letterCount(w) === n && !RARE.test(w)).sort();
    const pick = (list: string[], k: number, taken: Set<string>) => {
      const out: string[] = [];
      for (let tries = 0; out.length < k && tries < 200 && list.length; tries++) {
        const w = list[Math.floor(rand() * list.length)];
        if (!taken.has(w)) {
          taken.add(w);
          out.push(w);
        }
      }
      return out;
    };
    const taken = new Set<string>();
    return [...pick(pool(5), 2, taken), ...pick(pool(4), 2, taken)];
  }

  // -------------------------------------------------------------- podaci

  private async games(userId: string, since: Date): Promise<Played[]> {
    const rows = await this.prisma.matchPlayer.findMany({
      where: { userId, match: { status: 'FINISHED', endedAt: { gte: since } } },
      select: {
        livesLeft: true,
        wordsCount: true,
        board: true,
        match: { select: { endedAt: true, winnerId: true } },
      },
    });
    return rows.map((r) => {
      const endedAt = r.match.endedAt!;
      return {
        endedAt,
        day: dayKey(endedAt),
        week: weekKey(endedAt),
        month: monthKey(endedAt),
        win: r.match.winnerId === userId,
        noLifeLost: r.livesLeft >= 3,
        words: r.wordsCount,
        board: (r.board as (string | null)[] | null) ?? [],
      };
    });
  }

  private async pointsBy(userId: string, field: 'weekKey' | 'monthKey', keys: string[]) {
    const rows = await this.prisma.pointsEvent.groupBy({
      by: [field],
      where: { userId, [field]: { in: keys } },
      _sum: { delta: true },
    });
    return new Map(rows.map((r) => [(r as Record<string, unknown>)[field] as string, Math.floor(toPoints(r._sum.delta ?? 0))]));
  }

  private async claimedRefs(userId: string, refs: string[]) {
    const rows = await this.prisma.tokenTransaction.findMany({
      where: { userId, type: 'TASK_REWARD', externalRef: { in: refs } },
      select: { externalRef: true },
    });
    return new Set(rows.map((r) => r.externalRef));
  }

  private ref(userId: string, key: string, id: string) {
    return `task:${userId}:${key}:${id}`;
  }

  private view(defs: TaskDef[], c: Ctx, userId: string, key: string, claimed: Set<string | null>) {
    return defs.map((d) => {
      const progress = Math.min(d.target, Math.max(0, d.progress(c)));
      const done = progress >= d.target;
      return {
        id: d.id,
        title: d.title,
        target: d.target,
        progress,
        percent: Math.floor((progress / d.target) * 100),
        reward: d.reward,
        done,
        claimed: claimed.has(this.ref(userId, key, d.id)),
      };
    });
  }

  private allDone(defs: TaskDef[], c: Ctx) {
    return defs.every((d) => d.progress(c) >= d.target);
  }

  // -------------------------------------------------------------- pregled

  async overview(userId: string) {
    const now = new Date();
    const dk = dayKey(now);
    const wk = weekKey(now);
    const mk = monthKey(now);
    const all = await this.games(userId, new Date(now.getTime() - 32 * 86_400_000));
    const month = all.filter((g) => g.month === mk);
    const week = all.filter((g) => g.week === wk);
    const today = all.filter((g) => g.day === dk);

    // Za mesečne zadatke: dani u mesecu kad su ispunjeni svi dnevni, nedelje kad su ispunjeni svi nedeljni.
    const days = [...new Set(month.map((g) => g.day))];
    const challenges = await this.prisma.dailyChallenge.findMany({ where: { userId, dayKey: { in: days } } });
    const chByDay = new Map(challenges.map((c) => [c.dayKey, c.words as string[]]));
    let allDailyDays = 0;
    for (const d of days) {
      const c: Ctx = { games: month.filter((g) => g.day === d), points: 0, challenge: chByDay.get(d) ?? [] };
      if (this.allDone(DAILY, c) && (chByDay.has(d) ? MAIN.progress(c) >= MAIN.target : false)) allDailyDays++;
    }
    const weeks = [...new Set(month.map((g) => g.week))];
    const weekPts = await this.pointsBy(userId, 'weekKey', [...new Set([...weeks, wk])]);
    let allWeeklyWeeks = 0;
    for (const w of weeks) {
      const c: Ctx = { games: all.filter((g) => g.week === w), points: weekPts.get(w) ?? 0 };
      if (this.allDone(WEEKLY, c)) allWeeklyWeeks++;
    }
    const monthPts = (await this.pointsBy(userId, 'monthKey', [mk])).get(mk) ?? 0;

    const challenge = await this.challenge(userId, dk);
    const dayCtx: Ctx = { games: today, points: 0, challenge };
    const weekCtx: Ctx = { games: week, points: weekPts.get(wk) ?? 0 };
    const monthCtx: Ctx = { games: month, points: monthPts, allDailyDays, allWeeklyWeeks };

    const refs = [
      ...[...DAILY, MAIN].map((d) => this.ref(userId, dk, d.id)),
      ...WEEKLY.map((d) => this.ref(userId, wk, d.id)),
      ...MONTHLY.map((d) => this.ref(userId, mk, d.id)),
    ];
    const claimed = await this.claimedRefs(userId, refs);

    // Najbolja tabla danas za glavni zadatak (koje reči su složene na njoj).
    let bestHits = challenge.map(() => false);
    for (const g of today) {
      const h = challengeHits(g.board, challenge);
      if (h.filter(Boolean).length > bestHits.filter(Boolean).length) bestHits = h;
    }
    const [main] = this.view([MAIN], dayCtx, userId, dk, claimed);
    const day = this.view(DAILY, dayCtx, userId, dk, claimed);
    const weekly = this.view(WEEKLY, weekCtx, userId, wk, claimed);
    const monthly = this.view(MONTHLY, monthCtx, userId, mk, claimed);
    const claimable = [main, ...day, ...weekly, ...monthly].filter((t) => t.done && !t.claimed).length;
    return {
      claimable,
      day: {
        key: dk,
        endsAt: nextChange(now, dayKey, 50),
        main: { ...main, words: challenge.map((w, i) => ({ word: toLatin(w).toLowerCase(), done: bestHits[i] })) },
        tasks: day,
      },
      week: { key: wk, endsAt: nextChange(now, weekKey, 8 * 24 + 2), tasks: weekly },
      month: { key: mk, endsAt: nextChange(now, monthKey, 32 * 24), tasks: monthly },
    };
  }

  /** Preuzimanje nagrade za ispunjen zadatak. */
  async claim(userId: string, period: Period, id: string) {
    const o = await this.overview(userId);
    const list = period === 'day' ? [o.day.main, ...o.day.tasks] : period === 'week' ? o.week.tasks : o.month.tasks;
    const key = period === 'day' ? o.day.key : period === 'week' ? o.week.key : o.month.key;
    const t = list.find((x) => x.id === id);
    if (!t) throw new NotFoundException('Zadatak ne postoji.');
    if (!t.done) throw new BadRequestException('Zadatak još nije ispunjen.');
    if (t.claimed) throw new BadRequestException('Nagrada je već preuzeta.');
    try {
      const tx = await this.tokens.change(userId, t.reward, 'TASK_REWARD', {
        externalRef: this.ref(userId, key, id),
        note: t.title,
      });
      return { ok: true, reward: t.reward, tokens: tx.balanceAfter, title: t.title };
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new BadRequestException('Nagrada je već preuzeta.');
      }
      throw e;
    }
  }

  /** Koliko nagrada čeka (za crveni broj na pločici u meniju). */
  async claimable(userId: string) {
    return { claimable: (await this.overview(userId)).claimable };
  }
}

/** Trenutak kada se ključ perioda (dan/nedelja/mesec) menja — za odbrojavanje u aplikaciji. */
function nextChange(now: Date, keyOf: (d: Date) => string, maxHours: number) {
  const k = keyOf(now);
  let lo = now.getTime();
  let hi = lo + maxHours * 3_600_000;
  while (hi - lo > 1000) {
    const mid = Math.floor((lo + hi) / 2);
    if (keyOf(new Date(mid)) === k) lo = mid;
    else hi = mid;
  }
  return new Date(hi).toISOString();
}
