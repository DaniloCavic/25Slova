import { Injectable } from '@nestjs/common';
import { PointsReason, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { monthKey, yearKey } from '../common/time';

@Injectable()
export class PointsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Promena ukupnog, mesečnog i godišnjeg salda (jedan zapis važi za sva tri). */
  async apply(
    tx: Prisma.TransactionClient,
    userId: string,
    delta: number,
    reason: PointsReason,
    matchId?: string,
  ) {
    if (delta === 0) return;
    const now = new Date();
    await tx.user.update({ where: { id: userId }, data: { totalPoints: { increment: delta } } });
    await tx.pointsEvent.create({
      data: { userId, delta, reason, matchId, monthKey: monthKey(now), yearKey: yearKey(now) },
    });
  }

  async periodPoints(userId: string) {
    const now = new Date();
    const [m, y] = await Promise.all([
      this.prisma.pointsEvent.aggregate({ _sum: { delta: true }, where: { userId, monthKey: monthKey(now) } }),
      this.prisma.pointsEvent.aggregate({ _sum: { delta: true }, where: { userId, yearKey: yearKey(now) } }),
    ]);
    return { monthlyPoints: m._sum.delta ?? 0, yearlyPoints: y._sum.delta ?? 0 };
  }
}
