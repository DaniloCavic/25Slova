import { Body, Controller, Delete, Get, Param, ParseEnumPipe, Patch, Post, Put } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { User } from '@prisma/client';
import { ArrayMaxSize, IsArray, IsUUID } from 'class-validator';
import { CurrentUser, Public } from '../common/auth.guard';
import {
  AvatarDto,
  ChangePasswordDto,
  ForgotPasswordDto,
  LoginDto,
  RegisterDto,
  ResetPasswordDto,
  SocialCompleteDto,
  SocialLoginDto,
  UpdateProfileDto,
} from '../users/dto';
import { UsersService } from '../users/users.service';
import { TokensService } from '../tokens/tokens.service';
import { AuthService } from './auth.service';

enum Provider {
  google = 'google',
  apple = 'apple',
}

@Controller('auth')
@Throttle({ default: { limit: 10, ttl: 60_000 } })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public() @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Public() @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Public() @Post('forgot-password')
  forgot(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto.email);
  }

  @Public() @Post('reset-password')
  reset(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto);
  }

  @Public() @Post('social/:provider')
  social(@Param('provider', new ParseEnumPipe(Provider)) provider: Provider, @Body() dto: SocialLoginDto) {
    return this.auth.socialLogin(provider, dto);
  }

  @Public() @Post('social-complete')
  socialComplete(@Body() dto: SocialCompleteDto) {
    return this.auth.socialComplete(dto);
  }
}

class MedalsSeenDto {
  @IsArray()
  @ArrayMaxSize(50)
  @IsUUID('4', { each: true })
  ids: string[];
}

@Controller('me')
export class MeController {
  constructor(
    private readonly users: UsersService,
    private readonly auth: AuthService,
    private readonly tokens: TokensService,
  ) {}

  /** Profil; pri otvaranju aplikacije dodeljuje i dnevnu nagradu ako još nije preuzeta. */
  @Get()
  async me(@CurrentUser() user: User) {
    const daily = await this.tokens.claimDaily(user.id);
    const fresh = daily.granted ? { ...user, tokens: user.tokens + daily.amount } : user;
    return { user: await this.users.me(fresh), dailyReward: daily };
  }

  @Patch()
  update(@CurrentUser() user: User, @Body() dto: UpdateProfileDto) {
    return this.users.updateMe(user, dto);
  }

  @Post('password')
  password(@CurrentUser() user: User, @Body() dto: ChangePasswordDto) {
    return this.users.changePassword(user, dto);
  }

  @Put('avatar')
  avatar(@CurrentUser() user: User, @Body() dto: AvatarDto) {
    return this.users.setAvatar(user, dto.dataUrl);
  }

  @Delete('avatar')
  removeAvatar(@CurrentUser() user: User) {
    return this.users.removeAvatar(user);
  }

  @Get('medals')
  medals(@CurrentUser() user: User) {
    return this.users.medals(user.id);
  }

  @Get('medals/unseen')
  unseenMedals(@CurrentUser() user: User) {
    return this.users.unseenMedals(user.id);
  }

  @Post('medals/seen')
  medalsSeen(@CurrentUser() user: User, @Body() dto: MedalsSeenDto) {
    return this.users.markMedalsSeen(user.id, dto.ids);
  }

  @Post('link/:provider')
  link(
    @CurrentUser() user: User,
    @Param('provider', new ParseEnumPipe(Provider)) provider: Provider,
    @Body() dto: SocialLoginDto,
  ) {
    return this.auth.link(user, provider, dto.idToken);
  }

  @Delete()
  deleteAccount(@CurrentUser() user: User) {
    return this.users.deleteAccount(user.id);
  }
}
