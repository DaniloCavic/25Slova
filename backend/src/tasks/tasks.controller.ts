import { BadRequestException, Controller, Get, Param, Post } from '@nestjs/common';
import { User } from '@prisma/client';
import { CurrentUser } from '../common/auth.guard';
import { Period, TasksService } from './tasks.service';

@Controller('tasks')
export class TasksController {
  constructor(private readonly tasks: TasksService) {}

  /** Dnevni, nedeljni i mesečni zadaci sa napretkom. */
  @Get()
  overview(@CurrentUser() user: User) {
    return this.tasks.overview(user.id);
  }

  @Get('claimable')
  claimable(@CurrentUser() user: User) {
    return this.tasks.claimable(user.id);
  }

  @Post(':period/:id/claim')
  claim(@CurrentUser() user: User, @Param('period') period: string, @Param('id') id: string) {
    if (!['day', 'week', 'month'].includes(period)) throw new BadRequestException('Nepoznat period.');
    return this.tasks.claim(user.id, period as Period, id);
  }
}
