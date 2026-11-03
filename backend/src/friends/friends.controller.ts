import { BadRequestException, Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { User } from '@prisma/client';
import { CurrentUser } from '../common/auth.guard';
import { GameService } from '../game/game.service';
import { FriendsService } from './friends.service';

const STATUS_ORDER = { PLAYING: 0, ONLINE: 1, OFFLINE: 2 } as const;

@Controller('friends')
export class FriendsController {
  constructor(
    private readonly friends: FriendsService,
    private readonly game: GameService,
  ) {}

  /** Moji prijatelji: prvo oni u partiji, pa na mreži, pa van mreže (abecedno). */
  @Get()
  async list(@CurrentUser() user: User) {
    const list = (await this.friends.list(user.id)).map((f) => ({ ...f, status: this.game.playerStatus(f.id) }));
    list.sort(
      (a, b) => STATUS_ORDER[a.status] - STATUS_ORDER[b.status] || a.username.localeCompare(b.username, 'sr'),
    );
    return list;
  }

  /** Prijateljstvo preko ličnog linka za poziv. */
  @Post('link')
  link(@CurrentUser() user: User, @Body() body: { inviterId?: string }) {
    const id = String(body?.inviterId ?? '');
    if (!/^[0-9a-f-]{36}$/i.test(id)) throw new BadRequestException('Neispravan link.');
    return this.friends.addByLink(user.id, id);
  }

  @Delete(':id')
  remove(@CurrentUser() user: User, @Param('id', new ParseUUIDPipe()) id: string) {
    return this.friends.remove(user.id, id);
  }
}
