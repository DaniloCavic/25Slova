import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { levelForCents, toPoints } from '../game/engine/rules';
import { TokensService } from '../tokens/tokens.service';

/** Nagrada za poziv: dobijaju je i novi igrač i onaj ko ga je pozvao. */
export const INVITE_REWARD = 30;
/** Nagrada važi samo za nalog napravljen pre manje od 48 h (novi igrač). */
const INVITE_NEW_ACCOUNT_MS = 48 * 3600_000;
/** Najviše nagrađenih poziva mesečno po igraču (zaštita od lažnih naloga). */
const INVITE_MONTHLY_LIMIT = 20;

export interface HeadToHead {
  /** Pobede korisnika protiv prijatelja. */
  wins: number;
  /** Pobede prijatelja protiv korisnika. */
  losses: number;
  draws: number;
}

/** Lista prijatelja i međusobni skor. Prijateljstvo se čuva u oba smera. */
@Injectable()
export class FriendsService {
  /** Javlja aplikaciji da se lista promenila (postavlja GameService posle pokretanja Socket.IO). */
  onChange?: (userId: string, friendName: string, isNew: boolean) => void;
  /** Javlja onome ko je pozvao da je dobio nagradu (postavlja GameService). */
  onInviteReward?: (userId: string, friendName: string, amount: number) => void;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokensService,
  ) {}

  async areFriends(a: string, b: string) {
    return !!(await this.prisma.friendship.findUnique({ where: { userId_friendId: { userId: a, friendId: b } } }));
  }

  /** Napravi prijateljstvo (ako već ne postoji). Vraća true ako je novo. */
  async add(a: string, b: string, source: 'LINK' | 'CODE') {
    if (a === b) throw new BadRequestException('Ne možeš sam sebi biti prijatelj.');
    const res = await this.prisma.friendship.createMany({
      data: [
        { userId: a, friendId: b, source },
        { userId: b, friendId: a, source },
      ],
      skipDuplicates: true,
    });
    const isNew = res.count > 0;
    if (isNew && this.onChange) {
      const users = await this.prisma.user.findMany({ where: { id: { in: [a, b] } }, select: { id: true, username: true } });
      const name = (id: string) => users.find((u) => u.id === id)?.username ?? '';
      this.onChange(a, name(b), true);
      this.onChange(b, name(a), true);
    }
    return isNew;
  }

  /** Prijateljstvo preko ličnog linka (`?prijatelj=<id>`). */
  async addByLink(userId: string, inviterId: string) {
    const inviter = await this.prisma.user.findFirst({
      where: { id: inviterId, deletedAt: null },
      select: { id: true, username: true, isBlocked: true },
    });
    if (!inviter || inviter.isBlocked) throw new NotFoundException('Igrač iz linka ne postoji.');
    const isNew = await this.add(userId, inviter.id, 'LINK');
    const reward = isNew ? await this.inviteReward(userId, inviter.id, inviter.username) : 0;
    return { friend: { id: inviter.id, username: inviter.username }, isNew, reward };
  }

  /**
   * Novi igrač (nalog mlađi od 48 h) koji je došao preko linka: po 30 tokena njemu i onome ko ga je
   * pozvao. Svaki nalog donosi nagradu samo jednom (jedinstvena referenca), najviše 20 mesečno po igraču.
   */
  private async inviteReward(userId: string, inviterId: string, inviterName: string) {
    const me = await this.prisma.user.findUnique({ where: { id: userId }, select: { createdAt: true, username: true } });
    if (!me || Date.now() - me.createdAt.getTime() > INVITE_NEW_ACCOUNT_MS) return 0;
    const start = new Date();
    start.setUTCDate(1);
    start.setUTCHours(0, 0, 0, 0);
    const count = await this.prisma.tokenTransaction.count({
      where: { userId: inviterId, type: 'INVITE_REWARD', createdAt: { gte: start }, externalRef: { endsWith: ':inviter' } },
    });
    try {
      await this.prisma.$transaction(async (tx) => {
        await this.tokens.change(userId, INVITE_REWARD, 'INVITE_REWARD', { externalRef: `invite:${userId}`, note: `Poziv: ${inviterName}` }, tx);
        if (count < INVITE_MONTHLY_LIMIT) {
          await this.tokens.change(
            inviterId,
            INVITE_REWARD,
            'INVITE_REWARD',
            { externalRef: `invite:${userId}:inviter`, note: `Pozvan: ${me.username}` },
            tx,
          );
        }
      });
    } catch {
      return 0; // nagrada za ovaj nalog je već isplaćena
    }
    if (count < INVITE_MONTHLY_LIMIT) this.onInviteReward?.(inviterId, me.username, INVITE_REWARD);
    return INVITE_REWARD;
  }

  async remove(userId: string, friendId: string) {
    await this.prisma.friendship.deleteMany({
      where: {
        OR: [
          { userId, friendId },
          { userId: friendId, friendId: userId },
        ],
      },
    });
    this.onChange?.(userId, '', false);
    this.onChange?.(friendId, '', false);
    return { ok: true };
  }

  /** Međusobni skor u završenim partijama (sa prijateljem ili bilo kojim igračem). */
  async headToHead(userId: string, otherIds: string[]) {
    const out = new Map<string, HeadToHead>(otherIds.map((id) => [id, { wins: 0, losses: 0, draws: 0 }]));
    if (!otherIds.length) return out;
    const matches = await this.prisma.match.findMany({
      where: {
        status: 'FINISHED',
        AND: [{ players: { some: { userId } } }, { players: { some: { userId: { in: otherIds } } } }],
      },
      select: { winnerId: true, isDraw: true, players: { select: { userId: true } } },
    });
    for (const m of matches) {
      const other = m.players.find((p) => p.userId !== userId)?.userId;
      const h = other && out.get(other);
      if (!h) continue;
      if (m.isDraw) h.draws++;
      else if (m.winnerId === userId) h.wins++;
      else h.losses++;
    }
    return out;
  }

  /** Prijatelji sa levelom i međusobnim skorom (stanje „u igri / van mreže“ dodaje kontroler). */
  async list(userId: string) {
    const rows = await this.prisma.friendship.findMany({
      where: { userId, friend: { deletedAt: null } },
      include: {
        friend: { select: { id: true, username: true, avatarUrl: true, totalPoints: true, lastSeenAt: true } },
      },
    });
    const h2h = await this.headToHead(
      userId,
      rows.map((r) => r.friendId),
    );
    return rows.map((r) => ({
      id: r.friend.id,
      username: r.friend.username,
      avatarUrl: r.friend.avatarUrl,
      level: levelForCents(r.friend.totalPoints),
      totalPoints: toPoints(r.friend.totalPoints),
      lastSeenAt: r.friend.lastSeenAt,
      since: r.createdAt,
      h2h: h2h.get(r.friendId)!,
    }));
  }
}
