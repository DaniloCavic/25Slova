import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { levelForCents, toPoints } from '../game/engine/rules';

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

  constructor(private readonly prisma: PrismaService) {}

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
    return { friend: { id: inviter.id, username: inviter.username }, isNew };
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
