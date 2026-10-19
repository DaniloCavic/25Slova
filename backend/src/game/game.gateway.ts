import { Logger } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { User } from '@prisma/client';
import type { Server, Socket } from 'socket.io';
import { AuthGuard } from '../common/auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { GameError, GameService } from './game.service';

type AuthedSocket = Socket & { data: { userId: string } };

/**
 * Socket.IO kanal za igru. Klijent se povezuje sa { auth: { token } }.
 * Svaki događaj odgovara sa { ok: true, ... } ili { ok: false, error }.
 */
@WebSocketGateway({ cors: { origin: '*' }, path: '/socket.io' })
export class GameGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  private readonly log = new Logger(GameGateway.name);
  @WebSocketServer() server: Server;

  constructor(
    private readonly game: GameService,
    private readonly auth: AuthGuard,
    private readonly prisma: PrismaService,
  ) {}

  afterInit(server: Server) {
    this.game.attachServer(server);
  }

  async handleConnection(socket: AuthedSocket) {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;
      const user = await this.auth.userFromToken(String(token || ''));
      socket.data.userId = user.id;
      await socket.join(`user:${user.id}`);
      this.game.setPresence(socket.id, user.id, true);
      const resumed = this.game.resume(user.id);
      socket.emit('session', { userId: user.id, activeMatch: resumed });
    } catch (e) {
      socket.emit('auth:error', { error: (e as Error).message });
      socket.disconnect(true);
    }
  }

  async handleDisconnect(socket: AuthedSocket) {
    const userId = socket.data?.userId;
    this.game.removePresence(socket.id);
    if (!userId) return;
    const remaining = await this.server.in(`user:${userId}`).fetchSockets();
    if (remaining.length === 0) await this.game.onUserOffline(userId);
  }

  /** Uvek sveže iz baze (tokeni, blokada). */
  private async user(socket: AuthedSocket): Promise<User> {
    const u = await this.prisma.user.findUnique({ where: { id: socket.data.userId } });
    if (!u || u.isBlocked || u.deletedAt) {
      socket.disconnect(true);
      throw new GameError('Nalog nije aktivan.');
    }
    return u;
  }

  private async handle<T>(fn: () => Promise<T> | T) {
    try {
      const res = await fn();
      return { ok: true, ...(res && typeof res === 'object' ? res : {}) };
    } catch (e) {
      if (e instanceof GameError || (e as { status?: number }).status === 400) {
        return { ok: false, error: (e as Error).message };
      }
      this.log.error(e);
      return { ok: false, error: 'Greška na serveru. Pokušajte ponovo.' };
    }
  }

  @SubscribeMessage('queue:join')
  queueJoin(@ConnectedSocket() s: AuthedSocket) {
    return this.handle(async () => this.game.joinQueue(await this.user(s)));
  }

  @SubscribeMessage('queue:leave')
  queueLeave(@ConnectedSocket() s: AuthedSocket) {
    return this.handle(() => this.game.leaveQueue(s.data.userId));
  }

  @SubscribeMessage('private:create')
  privateCreate(@ConnectedSocket() s: AuthedSocket) {
    return this.handle(async () => this.game.createPrivate(await this.user(s)));
  }

  @SubscribeMessage('private:join')
  privateJoin(@ConnectedSocket() s: AuthedSocket, @MessageBody() body: { code?: string }) {
    return this.handle(async () => this.game.joinPrivate(await this.user(s), body?.code ?? ''));
  }

  @SubscribeMessage('private:cancel')
  privateCancel(@ConnectedSocket() s: AuthedSocket) {
    return this.handle(() => this.game.cancelPrivate(s.data.userId));
  }

  @SubscribeMessage('match:resume')
  resume(@ConnectedSocket() s: AuthedSocket) {
    return this.handle(() => ({ match: this.game.resume(s.data.userId) }));
  }

  @SubscribeMessage('match:move')
  move(@ConnectedSocket() s: AuthedSocket, @MessageBody() body: { cell?: number; letter?: string | null }) {
    return this.handle(() => this.game.move(s.data.userId, Number(body?.cell), body?.letter ?? null));
  }

  /** Aplikacija javlja da li je na ekranu (za obaveštenje „na potezu si“). */
  @SubscribeMessage('presence')
  presence(@ConnectedSocket() s: AuthedSocket, @MessageBody() body: { foreground?: boolean }) {
    return this.handle(() => {
      const fg = body?.foreground !== false;
      this.game.setPresence(s.id, s.data.userId, fg);
      if (fg) this.game.onForeground(s.data.userId);
      else this.game.onBackground(s.data.userId);
    });
  }

  @SubscribeMessage('rematch:request')
  rematchRequest(@ConnectedSocket() s: AuthedSocket, @MessageBody() body: { matchId?: string }) {
    return this.handle(async () => this.game.requestRematch(await this.user(s), String(body?.matchId ?? '')));
  }

  @SubscribeMessage('rematch:decline')
  rematchDecline(@ConnectedSocket() s: AuthedSocket, @MessageBody() body: { matchId?: string }) {
    return this.handle(() => this.game.declineRematch(s.data.userId, String(body?.matchId ?? '')));
  }

  @SubscribeMessage('match:resign')
  resign(@ConnectedSocket() s: AuthedSocket) {
    return this.handle(() => this.game.resign(s.data.userId));
  }
}
