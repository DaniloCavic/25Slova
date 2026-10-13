import { Injectable } from '@nestjs/common';
import { PointsReason, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { monthKey, weekKey, yearKey } from '../common/time';
import { toPoints } from '../game/engine/rules';

@Injectable()
export class PointsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Promena ukupnog, nedeljnog, mesečnog i godišnjeg salda; delta je u stotinkama poena. */
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
      data: { userId, delta, reason, matchId, weekKey: weekKey(now), monthKey: monthKey(now), yearKey: yearKey(now) },
    });
  }

  async periodPoints(userId: string) {
    const now = new Date();
    const [w, m, y] = await Promise.all([
      this.prisma.pointsEvent.aggregate({ _sum: { delta: true }, where: { userId, weekKey: weekKey(now) } }),
      this.prisma.pointsEvent.aggregate({ _sum: { delta: true }, where: { userId, monthKey: monthKey(now) } }),
      this.prisma.pointsEvent.aggregate({ _sum: { delta: true }, where: { userId, yearKey: yearKey(now) } }),
    ]);
    return {
      weeklyPoints: toPoints(w._sum.delta ?? 0),
      monthlyPoints: toPoints(m._sum.delta ?? 0),
      yearlyPoints: toPoints(y._sum.delta ?? 0),
    };
  }
}
