import { Controller, Get, Query } from '@nestjs/common';
import { User } from '@prisma/client';
import { CurrentUser } from '../common/auth.guard';
import { LeaderboardService, Period } from './leaderboard.service';

@Controller()
export class LeaderboardController {
  constructor(private readonly lb: LeaderboardService) {}

  @Get('leaderboard')
  leaderboard(
    @CurrentUser() user: User,
    @Query('period') period?: string,
    @Query('key') key?: string,
    @Query('search') search?: string,
  ) {
    const p: Period = period === 'week' || period === 'year' ? period : 'month';
    const k = key && /^\d{4}(-W?\d{2})?$/.test(key) ? key : undefined;
    return this.lb.leaderboard(p, k, user.id, search);
  }

  @Get('best-board')
  best() {
    return this.lb.bestBoards();
  }
}
