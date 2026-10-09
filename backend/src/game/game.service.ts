import { BadRequestException, Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { randomInt } from 'crypto';
import type { Server } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';
import { TokensService } from '../tokens/tokens.service';
import { PointsService } from '../users/points.service';
import { DictionaryService } from '../words/dictionary.service';
import { SettingsService } from '../settings/settings.service';
import { levelForPoints, MATCH_ENTRY_COST, MATCH_TYPES, randomMatchType } from './engine/rules';
import {
  applyMove,
  applyResign,
  applyTimeout,
  computeResult,
  createMatchState,
  MatchResult,
  MatchState,
  MoveError,
  other,
  Seat,
} from './engine/match-state';

interface PlayerInfo {
  userId: string;
  username: string;
  avatarUrl: string | null;
  level: number;
}

interface Runtime {
  matchId: string;
  mode: 'RANDOM' | 'PRIVATE';
  players: [PlayerInfo, PlayerInfo];
  state: MatchState;
  timer?: NodeJS.Timeout;
  ending: boolean;
  saving: Promise<unknown>;
}

interface QueueEntry {
  user: PlayerInfo;
  joinedAt: number;
}

interface PrivateGame {
  matchId: string;
  code: string;
  host: PlayerInfo;
  expiresAt: number;
}

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export class GameError extends Error {}

/**
 * Sva logika partija u realnom vremenu. Server je jedini sudija:
 * on određuje tajmer, živote, prihvatanje poteza, rezultat i tokene.
 *
 * Napomena za skaliranje: red čekanja i partije u toku se drže u memoriji jednog
 * procesa. Za više instanci servera stanje treba premestiti u Redis.
 */
@Injectable()
export class GameService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly log = new Logger(GameService.name);
  private server?: Server;
  private readonly matches = new Map<string, Runtime>();
  private readonly userMatch = new Map<string, string>();
  private readonly queue = new Map<string, QueueEntry>();
  private readonly privateByCode = new Map<string, PrivateGame>();
  private readonly privateByHost = new Map<string, PrivateGame>();
  private ticker?: NodeJS.Timeout;
  private pairing = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokensService,
    private readonly points: PointsService,
    private readonly dict: DictionaryService,
    private readonly settings: SettingsService,
  ) {}

  async onApplicationBootstrap() {
    await this.settings.load();
    await this.recoverInterruptedMatches();
    this.ticker = setInterval(() => void this.tick(), 1000);
  }

  onModuleDestroy() {
    clearInterval(this.ticker);
    for (const r of this.matches.values()) clearTimeout(r.timer);
  }

  attachServer(server: Server) {
    this.server = server;
  }

  private emitUser(userId: string, event: string, payload: unknown) {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }

  /** Partije prekinute restartom servera se poništavaju i tokeni vraćaju. */
  private async recoverInterruptedMatches() {
    const stale = await this.prisma.match.findMany({
      where: { status: { in: ['ACTIVE', 'WAITING'] } },
      include: { players: true },
    });
    for (const m of stale) {
      await this.prisma.$transaction(async (tx) => {
        await tx.match.update({
          where: { id: m.id },
          data: { status: m.status === 'ACTIVE' ? 'ABORTED' : 'CANCELLED', endedAt: new Date() },
        });
        if (m.status === 'ACTIVE') {
          for (const p of m.players) {
            await this.tokens.change(p.userId, MATCH_ENTRY_COST, 'MATCH_REFUND', {
              matchId: m.id,
              note: 'Partija prekinuta zbog restarta servera',
            }, tx);
          }
        }
      });
    }
    if (stale.length) this.log.warn(`Poništeno ${stale.length} nezavršenih partija posle restarta.`);
  }

  private playerInfo(u: User): PlayerInfo {
    return { userId: u.id, username: u.username, avatarUrl: u.avatarUrl, level: levelForPoints(u.totalPoints) };
  }

  private assertFree(user: User) {
    if (this.userMatch.has(user.id)) throw new GameError('Već ste u partiji.');
    if (this.queue.has(user.id)) throw new GameError('Već tražite protivnika.');
    if (this.privateByHost.has(user.id)) throw new GameError('Već čekate igrača za privatnu partiju.');
    if (user.tokens < MATCH_ENTRY_COST) throw new GameError(`Za partiju je potrebno ${MATCH_ENTRY_COST} tokena.`);
  }

  // ---------------------------------------------------------------- red čekanja

  joinQueue(user: User) {
    this.assertFree(user);
    this.queue.set(user.id, { user: this.playerInfo(user), joinedAt: Date.now() });
    this.emitUser(user.id, 'queue:joined', { cost: MATCH_ENTRY_COST });
  }

  leaveQueue(userId: string) {
    if (this.queue.delete(userId)) this.emitUser(userId, 'queue:left', {});
  }

  private allowedRange(entry: QueueEntry, now: number) {
    const s = this.settings.matchmaking;
    const waited = (now - entry.joinedAt) / 1000;
    return Math.min(s.maxLevelRange, s.initialLevelRange + Math.floor(waited / s.expandEverySeconds));
  }

  /** Uparivanje: prvo igrači sličnog levela, raspon se postepeno širi dok igrač čeka. */
  private async pairQueue() {
    if (this.pairing || this.queue.size < 2) return;
    this.pairing = true;
    try {
      const now = Date.now();
      const entries = [...this.queue.values()].sort((a, b) => a.joinedAt - b.joinedAt);
      const used = new Set<string>();
      for (const a of entries) {
        if (used.has(a.user.userId)) continue;
        let best: QueueEntry | undefined;
        for (const b of entries) {
          if (b === a || used.has(b.user.userId)) continue;
          const diff = Math.abs(a.user.level - b.user.level);
          const allowed = Math.max(this.allowedRange(a, now), this.allowedRange(b, now));
          if (diff > allowed) continue;
          if (!best || diff < Math.abs(a.user.level - best.user.level)) best = b;
        }
        if (!best) continue;
        used.add(a.user.userId);
        used.add(best.user.userId);
        this.queue.delete(a.user.userId);
        this.queue.delete(best.user.userId);
        await this.startMatch([a.user, best.user], 'RANDOM').catch((e) => {
          // Npr. jedan od igrača više nema dovoljno tokena — drugi se vraća u red.
          this.log.warn(`Uparivanje nije uspelo: ${e.message}`);
          for (const p of [a, best!]) {
            if (!(e instanceof InsufficientTokens && e.userId === p.user.userId)) this.queue.set(p.user.userId, p);
          }
        });
      }
    } finally {
      this.pairing = false;
    }
  }

  // ---------------------------------------------------------- privatna partija

  async createPrivate(user: User) {
    this.assertFree(user);
    const minutes = this.settings.matchmaking.privateCodeMinutes;
    let code = '';
    do {
      code = Array.from({ length: 6 }, () => CODE_ALPHABET[randomInt(CODE_ALPHABET.length)]).join('');
    } while (this.privateByCode.has(code));
    const expiresAt = Date.now() + minutes * 60_000;
    const match = await this.prisma.match.create({
      data: {
        mode: 'PRIVATE',
        status: 'WAITING',
        type: 0,
        code,
        codeExpiresAt: new Date(expiresAt),
      },
    });
    const pg: PrivateGame = { matchId: match.id, code, host: this.playerInfo(user), expiresAt };
    this.privateByCode.set(code, pg);
    this.privateByHost.set(user.id, pg);
    this.emitUser(user.id, 'private:created', { code, expiresAt, cost: MATCH_ENTRY_COST });
    return { code, expiresAt };
  }

  async cancelPrivate(userId: string, reason = 'Otkazano.') {
    const pg = this.privateByHost.get(userId);
    if (!pg) return;
    this.privateByHost.delete(userId);
    this.privateByCode.delete(pg.code);
    await this.prisma.match.update({ where: { id: pg.matchId }, data: { status: 'CANCELLED', endedAt: new Date() } });
    this.emitUser(userId, 'private:cancelled', { reason });
  }

  async joinPrivate(user: User, rawCode: string) {
    const code = (rawCode || '').trim().toUpperCase();
    const pg = this.privateByCode.get(code);
    if (!pg || pg.expiresAt < Date.now()) throw new GameError('Kod ne postoji ili je istekao.');
    if (pg.host.userId === user.id) throw new GameError('Ne možete igrati sami protiv sebe.');
    this.assertFree(user);
    if (!(await this.isOnline(pg.host.userId))) throw new GameError('Igrač koji je kreirao partiju nije trenutno povezan.');
    this.privateByCode.delete(code);
    this.privateByHost.delete(pg.host.userId);
    try {
      await this.startMatch([pg.host, this.playerInfo(user)], 'PRIVATE', pg.matchId);
    } catch (e) {
      if (e instanceof InsufficientTokens && e.userId === pg.host.userId) {
        await this.prisma.match.update({ where: { id: pg.matchId }, data: { status: 'CANCELLED' } });
        this.emitUser(pg.host.userId, 'private:cancelled', { reason: 'Nemate dovoljno tokena.' });
        throw new GameError('Protivnik nema dovoljno tokena.');
      }
      // Vraćamo kod da bi neko drugi mogao da se pridruži.
      this.privateByCode.set(code, pg);
      this.privateByHost.set(pg.host.userId, pg);
      throw e;
    }
  }

  private async isOnline(userId: string) {
    if (!this.server) return false;
    const sockets = await this.server.in(`user:${userId}`).fetchSockets();
    return sockets.length > 0;
  }

  // ------------------------------------------------------------------ partija

  /**
   * Početak partije: tokeni (10 po igraču) se oduzimaju tek kada je protivnik
   * pronađen, u istoj transakciji za oba igrača — niko ne plaća partiju koja ne počne.
   */
  private async startMatch(players: [PlayerInfo, PlayerInfo], mode: 'RANDOM' | 'PRIVATE', existingMatchId?: string) {
    const type = randomMatchType();
    const now = Date.now();
    const state = createMatchState(type, now);

    const matchId = await this.prisma.$transaction(async (tx) => {
      const data = {
        mode,
        type,
        status: 'ACTIVE' as const,
        startedAt: new Date(now),
        initialCells: state.initialCells as unknown as Prisma.InputJsonValue,
        state: state as unknown as Prisma.InputJsonValue,
      };
      const m = existingMatchId
        ? await tx.match.update({ where: { id: existingMatchId }, data })
        : await tx.match.create({ data });
      for (const [seat, p] of players.entries()) {
        try {
          await this.tokens.change(p.userId, -MATCH_ENTRY_COST, 'MATCH_ENTRY', { matchId: m.id }, tx);
        } catch {
          throw new InsufficientTokens(p.userId);
        }
        await tx.matchPlayer.create({
          data: { matchId: m.id, userId: p.userId, seat, initialLetters: state.initialCells.length },
        });
      }
      return m.id;
    });

    const rt: Runtime = { matchId, mode, players, state, ending: false, saving: Promise.resolve() };
    this.matches.set(matchId, rt);
    players.forEach((p) => this.userMatch.set(p.userId, matchId));
    this.schedule(rt);
    players.forEach((p, seat) => {
      this.emitUser(p.userId, 'match:start', this.view(rt, seat as Seat));
      void this.sendTokenBalance(p.userId);
    });
    this.log.log(`Partija ${matchId} (${mode}, tip ${type}) počela: ${players.map((p) => p.username).join(' vs ')}`);
  }

  private async sendTokenBalance(userId: string) {
    const u = await this.prisma.user.findUnique({ where: { id: userId }, select: { tokens: true } });
    if (u) this.emitUser(userId, 'tokens:balance', { tokens: u.tokens });
  }

  private schedule(rt: Runtime) {
    clearTimeout(rt.timer);
    const delay = Math.max(0, rt.state.deadline - Date.now()) + 50;
    rt.timer = setTimeout(() => this.onTimer(rt), delay);
  }

  private onTimer(rt: Runtime) {
    if (rt.ending) return;
    const before = rt.state;
    let s = rt.state;
    const now = Date.now();
    while (s.phase !== 'ENDED' && now >= s.deadline) s = applyTimeout(s, now);
    rt.state = s;
    if (s !== before) {
      const lost = before.actor;
      this.emitBoth(rt, 'match:life-lost', { seat: lost, livesLeft: s.lives[lost] });
    }
    this.afterChange(rt);
  }

  private afterChange(rt: Runtime) {
    this.persist(rt);
    if (rt.state.phase === 'ENDED') {
      void this.finish(rt);
    } else {
      this.schedule(rt);
      rt.players.forEach((p, seat) => this.emitUser(p.userId, 'match:state', this.view(rt, seat as Seat)));
    }
  }

  private persist(rt: Runtime) {
    const state = rt.state;
    rt.saving = rt.saving
      .then(() =>
        this.prisma.match.update({
          where: { id: rt.matchId },
          data: { state: state as unknown as Prisma.InputJsonValue },
        }),
      )
      .catch((e) => this.log.error(`Čuvanje stanja partije ${rt.matchId}: ${e}`));
  }

  private emitBoth(rt: Runtime, event: string, payload: unknown) {
    rt.players.forEach((p) => this.emitUser(p.userId, event, payload));
  }

  private runtimeFor(userId: string): { rt: Runtime; seat: Seat } {
    const id = this.userMatch.get(userId);
    const rt = id ? this.matches.get(id) : undefined;
    if (!rt) throw new GameError('Niste u partiji.');
    const seat = rt.players.findIndex((p) => p.userId === userId) as Seat;
    return { rt, seat };
  }

  move(userId: string, cell: number, letter: string | null) {
    const { rt, seat } = this.runtimeFor(userId);
    if (rt.ending) throw new GameError('Partija je završena.');
    try {
      rt.state = applyMove(rt.state, seat, cell, letter, Date.now());
    } catch (e) {
      if (e instanceof MoveError) throw new GameError(e.message);
      throw e;
    }
    this.afterChange(rt);
  }

  resign(userId: string) {
    const { rt, seat } = this.runtimeFor(userId);
    if (rt.ending) return;
    rt.state = applyResign(rt.state, seat);
    this.afterChange(rt);
  }

  /** Ponovno povezivanje: igrač dobija trenutno stanje svoje partije (vreme je sve vreme teklo). */
  resume(userId: string) {
    const id = this.userMatch.get(userId);
    const rt = id ? this.matches.get(id) : undefined;
    if (!rt) return null;
    const seat = rt.players.findIndex((p) => p.userId === userId) as Seat;
    return this.view(rt, seat);
  }

  /** Stanje iz ugla jednog igrača. Protivnikova tabla se ne otkriva dok partija traje. */
  private view(rt: Runtime, seat: Seat) {
    const s = rt.state;
    const opp = other(seat);
    return {
      matchId: rt.matchId,
      mode: rt.mode,
      type: s.type,
      initialLetters: MATCH_TYPES[s.type].initialLetters,
      turnSeconds: s.turnSeconds,
      mySeat: seat,
      me: { ...rt.players[seat], lives: s.lives[seat], board: s.boards[seat] },
      opponent: {
        ...rt.players[opp],
        lives: s.lives[opp],
        filled: s.boards[opp].filter(Boolean).length,
      },
      initialCells: s.initialCells.map((c) => c.cell),
      phase: s.phase,
      actorSeat: s.actor,
      isMyTurn: s.actor === seat && s.phase !== 'ENDED',
      currentLetter: s.currentLetter,
      deadline: s.deadline,
      serverNow: Date.now(),
      moveCount: s.moves.length,
    };
  }

  private async finish(rt: Runtime) {
    if (rt.ending) return;
    rt.ending = true;
    clearTimeout(rt.timer);
    const s = rt.state;
    const result: MatchResult = computeResult(s, this.dict.has);
    const winnerId = result.winner === null ? null : rt.players[result.winner].userId;

    await rt.saving;
    await this.prisma.$transaction(async (tx) => {
      await tx.match.update({
        where: { id: rt.matchId },
        data: {
          status: 'FINISHED',
          endReason: s.endReason,
          winnerId,
          isDraw: result.winner === null,
          endedAt: new Date(),
          state: s as unknown as Prisma.InputJsonValue,
        },
      });
      for (const seat of [0, 1] as Seat[]) {
        const p = rt.players[seat];
        const sc = result.scores[seat];
        await tx.matchPlayer.update({
          where: { matchId_seat: { matchId: rt.matchId, seat } },
          data: {
            board: s.boards[seat] as unknown as Prisma.InputJsonValue,
            score: sc.points,
            wordsCount: sc.wordsCount,
            words: sc.lines.filter((l) => l.word).map((l) => ({ word: l.word, kind: l.kind, index: l.index, cells: l.wordCells, points: l.points })) as unknown as Prisma.InputJsonValue,
            livesLeft: s.lives[seat],
            pointsDelta: result.pointsDelta[seat],
          },
        });
        const delta = result.pointsDelta[seat];
        if (delta !== 0) await this.points.apply(tx, p.userId, delta, delta > 0 ? 'WIN' : 'LOSS', rt.matchId);
      }
    });

    const totals = await this.prisma.user.findMany({
      where: { id: { in: rt.players.map((p) => p.userId) } },
      select: { id: true, totalPoints: true },
    });
    rt.players.forEach((p, seat) => {
      const opp = other(seat as Seat);
      const total = totals.find((t) => t.id === p.userId)?.totalPoints ?? 0;
      this.emitUser(p.userId, 'match:end', {
        matchId: rt.matchId,
        outcome: result.winner === null ? 'DRAW' : result.winner === seat ? 'WIN' : 'LOSS',
        endReason: s.endReason,
        pointsDelta: result.pointsDelta[seat],
        totalPoints: total,
        level: levelForPoints(total),
        initialCells: s.initialCells.map((c) => c.cell),
        me: this.boardResult(s, result, seat as Seat, rt.players[seat]),
        opponent: this.boardResult(s, result, opp, rt.players[opp]),
      });
    });
    this.matches.delete(rt.matchId);
    rt.players.forEach((p) => this.userMatch.delete(p.userId));
    this.log.log(`Partija ${rt.matchId} završena (${s.endReason}), pobednik: ${winnerId ?? 'nerešeno'}`);
  }

  private boardResult(s: MatchState, r: MatchResult, seat: Seat, p: PlayerInfo) {
    const sc = r.scores[seat];
    return {
      username: p.username,
      avatarUrl: p.avatarUrl,
      board: s.boards[seat],
      lives: s.lives[seat],
      points: sc.points,
      wordsCount: sc.wordsCount,
      lines: sc.lines.map((l) => ({ kind: l.kind, index: l.index, word: l.word, points: l.points, cells: l.wordCells })),
    };
  }

  // ----------------------------------------------------------------- ostalo

  private async tick() {
    const now = Date.now();
    for (const pg of [...this.privateByHost.values()]) {
      if (pg.expiresAt < now) await this.cancelPrivate(pg.host.userId, 'Kod je istekao.').catch(() => undefined);
    }
    await this.pairQueue();
  }

  /** Igrač je napustio aplikaciju (sve konekcije zatvorene). Partija nastavlja da teče. */
  async onUserOffline(userId: string) {
    this.queue.delete(userId);
    // Privatna partija ostaje otvorena dok kod ne istekne; pridruživanje proverava da li je domaćin povezan.
  }

  /** Admin je blokirao ili obrisao korisnika: izlazi iz reda, predaje partiju, gubi konekciju. */
  async kick(userId: string, reason: string) {
    this.queue.delete(userId);
    await this.cancelPrivate(userId).catch(() => undefined);
    if (this.userMatch.has(userId)) {
      try {
        this.resign(userId);
      } catch {
        /* partija se već završava */
      }
    }
    this.emitUser(userId, 'account:blocked', { reason });
    this.server?.in(`user:${userId}`).disconnectSockets(true);
  }

  stats() {
    return {
      activeMatches: this.matches.size,
      inQueue: this.queue.size,
      privateWaiting: this.privateByCode.size,
    };
  }
}

export class InsufficientTokens extends BadRequestException {
  constructor(readonly userId: string) {
    super('Nemate dovoljno tokena.');
  }
}
