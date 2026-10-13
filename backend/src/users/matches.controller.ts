import { Controller, Get } from '@nestjs/common';
import { User } from '@prisma/client';
import { CurrentUser } from '../common/auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { toPoints } from '../game/engine/rules';

@Controller('matches')
export class MatchesController {
  constructor(private readonly prisma: PrismaService) {}

  /** Poslednje odigrane partije korisnika. */
  @Get('recent')
  async recent(@CurrentUser() user: User) {
    const rows = await this.prisma.matchPlayer.findMany({
      where: { userId: user.id, match: { status: 'FINISHED' } },
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: {
        match: {
          select: {
            mode: true,
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
      const opp = r.match.players.find((p) => p.userId !== user.id);
      return {
        matchId: r.matchId,
        mode: r.match.mode,
        endReason: r.match.endReason,
        outcome: r.match.isDraw ? 'DRAW' : r.match.winnerId === user.id ? 'WIN' : 'LOSS',
        myScore: r.score,
        myWords: r.wordsCount,
        opponent: opp?.user.username ?? null,
        opponentScore: opp?.score ?? null,
        pointsDelta: toPoints(r.pointsDelta),
        endedAt: r.match.endedAt,
      };
    });
  }
}
