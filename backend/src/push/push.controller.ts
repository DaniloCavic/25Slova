import { Body, Controller, Get, Post } from '@nestjs/common';
import { User } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsIn, IsOptional, IsString, MaxLength, ValidateNested } from 'class-validator';
import { CurrentUser } from '../common/auth.guard';
import { PushService } from './push.service';

class WebKeysDto {
  @IsString() @MaxLength(200) p256dh: string;
  @IsString() @MaxLength(100) auth: string;
}

class WebSubscriptionDto {
  @IsString() @MaxLength(1000) endpoint: string;
  @ValidateNested() @Type(() => WebKeysDto) keys: WebKeysDto;
}

class SubscribeDto {
  @IsIn(['WEB', 'FCM']) kind: 'WEB' | 'FCM';
  @IsOptional() @ValidateNested() @Type(() => WebSubscriptionDto) subscription?: WebSubscriptionDto;
  @IsOptional() @IsString() @MaxLength(1000) token?: string;
}

class UnsubscribeDto {
  @IsString() @MaxLength(1000) endpoint: string;
}

@Controller('push')
export class PushController {
  constructor(private readonly push: PushService) {}

  /** Javni VAPID ključ za Web Push i da li je FCM uključen. */
  @Get('config')
  config() {
    return this.push.config();
  }

  @Post('subscribe')
  async subscribe(@CurrentUser() user: User, @Body() dto: SubscribeDto) {
    if (dto.kind === 'WEB' && dto.subscription) await this.push.subscribeWeb(user.id, dto.subscription);
    else if (dto.kind === 'FCM' && dto.token) await this.push.subscribeFcm(user.id, dto.token);
    return { ok: true };
  }

  @Post('unsubscribe')
  async unsubscribe(@CurrentUser() user: User, @Body() dto: UnsubscribeDto) {
    await this.push.unsubscribe(user.id, dto.endpoint);
    return { ok: true };
  }

  /** Probno obaveštenje (iz podešavanja aplikacije). */
  @Post('test')
  async test(@CurrentUser() user: User) {
    await this.push.send(user.id, { title: '25 Slova', body: 'Obaveštenja rade! 🔔', tag: 'test' });
    return { ok: true };
  }
}
