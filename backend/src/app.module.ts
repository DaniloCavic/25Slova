import { ExecutionContext, Injectable, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.service';
import { AuthGuard } from './common/auth.guard';
import { AuthController, MeController } from './auth/auth.controller';
import { AuthService } from './auth/auth.service';
import { MailService } from './auth/mail.service';
import { SocialVerifierService } from './auth/social-verifier.service';
import { UsersService } from './users/users.service';
import { PointsService } from './users/points.service';
import { MatchesController, MatchHistoryService, PlayersController } from './users/matches.controller';
import { TokensService } from './tokens/tokens.service';
import { TokensController } from './tokens/tokens.controller';
import { AdVerifierService } from './tokens/ad-verifier.service';
import { DictionaryService } from './words/dictionary.service';
import { AdminWordsController } from './words/words.controller';
import { AdminController } from './admin/admin.controller';
import { SettingsService } from './settings/settings.service';
import { GameService } from './game/game.service';
import { GameGateway } from './game/game.gateway';
import { LeaderboardService } from './leaderboard/leaderboard.service';
import { LeaderboardController } from './leaderboard/leaderboard.controller';
import { HealthController } from './health.controller';
import { PushService } from './push/push.service';
import { PushController } from './push/push.controller';

/** Ograničenje broja zahteva važi samo za HTTP (ne za Socket.IO). */
@Injectable()
class HttpThrottlerGuard extends ThrottlerGuard {
  canActivate(ctx: ExecutionContext) {
    return ctx.getType() === 'http' ? super.canActivate(ctx) : Promise.resolve(true);
  }
}

@Module({
  imports: [
    PrismaModule,
    ScheduleModule.forRoot(),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    JwtModule.register({
      global: true,
      secret: process.env.JWT_SECRET,
      signOptions: { expiresIn: (process.env.JWT_EXPIRES_IN || '30d') as never },
    }),
  ],
  controllers: [
    HealthController,
    AuthController,
    MeController,
    MatchesController,
    PlayersController,
    TokensController,
    AdminWordsController,
    AdminController,
    LeaderboardController,
    PushController,
  ],
  providers: [
    AuthGuard,
    { provide: APP_GUARD, useClass: HttpThrottlerGuard },
    { provide: APP_GUARD, useExisting: AuthGuard },
    AuthService,
    MailService,
    SocialVerifierService,
    UsersService,
    PointsService,
    MatchHistoryService,
    TokensService,
    AdVerifierService,
    DictionaryService,
    SettingsService,
    GameService,
    GameGateway,
    LeaderboardService,
    PushService,
  ],
})
export class AppModule {}
