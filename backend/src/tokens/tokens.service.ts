import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma, TokenTxType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { dayKey } from '../common/time';
import { DAILY_REWARD } from '../game/engine/rules';

type Tx = Prisma.TransactionClient;

@Injectable()
export class TokensService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Promena stanja tokena + zapis transakcije, atomski.
   * Kod oduzimanja stanje ne sme pasti ispod nule.
   */
  async change(
    userId: string,
    amount: number,
    type: TokenTxType,
    opts: { matchId?: string; externalRef?: string; note?: string; allowNegative?: boolean } = {},
    tx?: Tx,
  ) {
    const run = async (db: Tx) => {
      const where: Prisma.UserWhereInput = { id: userId };
      if (amount < 0 && !opts.allowNegative) where.tokens = { gte: -amount };
      const res = await db.user.updateMany({ where, data: { tokens: { increment: amount } } });
      if (res.count === 0) throw new BadRequestException('Nemate dovoljno tokena.');
      const user = await db.user.findUniqueOrThrow({ where: { id: userId }, select: { tokens: true } });
      return db.tokenTransaction.create({
        data: {
          userId,
          type,
          amount,
          balanceAfter: user.tokens,
          matchId: opts.matchId,
          externalRef: opts.externalRef,
          note: opts.note,
        },
      });
    };
    return tx ? run(tx) : this.prisma.$transaction(run);
  }

  /**
   * Dnevna nagrada: 30 tokena pri prvoj prijavi tokom kalendarskog dana.
   * Uslov u UPDATE-u garantuje da se nagrada ne može preuzeti dvaput,
   * čak ni kod istovremenih zahteva.
   */
  async claimDaily(userId: string): Promise<{ granted: boolean; amount: number }> {
    const today = dayKey();
    return this.prisma.$transaction(async (tx) => {
      const res = await tx.user.updateMany({
        where: {
          id: userId,
          OR: [{ lastDailyRewardDay: null }, { lastDailyRewardDay: { not: today } }],
        },
        data: { lastDailyRewardDay: today },
      });
      if (res.count === 0) return { granted: false, amount: 0 };
      await this.change(userId, DAILY_REWARD, 'DAILY_REWARD', { externalRef: `daily:${userId}:${today}` }, tx);
      return { granted: true, amount: DAILY_REWARD };
    });
  }

  history(userId: string, take = 50) {
    return this.prisma.tokenTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take,
      select: { id: true, type: true, amount: true, balanceAfter: true, note: true, createdAt: true },
    });
  }
}
