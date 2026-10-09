import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export const IS_PUBLIC = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC, true);
export const ADMIN_ONLY = 'adminOnly';
export const AdminOnly = () => SetMetadata(ADMIN_ONLY, true);

export interface JwtPayload {
  sub: string;
  role: string;
}

export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): User => {
  return ctx.switchToHttp().getRequest().user;
});

/**
 * Globalni guard: svaki zahtev mora imati važeći token osim onih označenih sa @Public().
 * Korisnik se učitava iz baze pri svakom zahtevu, pa blokada važi odmah.
 */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    // Socket.IO konekcije proverava GameGateway pri povezivanju.
    if (ctx.getType() !== 'http') return true;
    const targets = [ctx.getHandler(), ctx.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;

    const req = ctx.switchToHttp().getRequest();
    const header: string | undefined = req.headers['authorization'];
    const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
    if (!token) throw new UnauthorizedException('Niste prijavljeni.');
    const user = await this.userFromToken(token);
    req.user = user;

    if (this.reflector.getAllAndOverride<boolean>(ADMIN_ONLY, targets) && user.role !== 'ADMIN') {
      throw new ForbiddenException('Samo za administratore.');
    }
    return true;
  }

  async userFromToken(token: string): Promise<User> {
    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(token);
    } catch {
      throw new UnauthorizedException('Sesija je istekla. Prijavite se ponovo.');
    }
    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || user.deletedAt) throw new UnauthorizedException('Nalog ne postoji.');
    if (user.isBlocked) {
      throw new ForbiddenException(
        user.blockedReason ? `Nalog je blokiran: ${user.blockedReason}` : 'Nalog je blokiran.',
      );
    }
    return user;
  }
}
