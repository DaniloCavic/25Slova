import { Controller, Get, Logger, Req } from '@nestjs/common';
import { User } from '@prisma/client';
import type { Request } from 'express';
import { CurrentUser, Public } from '../common/auth.guard';
import { AD_REWARD } from '../game/engine/rules';
import { AdVerifierService } from './ad-verifier.service';
import { TokensService } from './tokens.service';

@Controller('tokens')
export class TokensController {
  private readonly log = new Logger(TokensController.name);
  constructor(
    private readonly tokens: TokensService,
    private readonly ads: AdVerifierService,
  ) {}

  @Get('history')
  history(@CurrentUser() user: User) {
    return this.tokens.history(user.id);
  }

  /**
   * AdMob SSV callback. U AdMob konzoli se podesi URL:
   *   https://<server>/api/tokens/ad-callback
   * a aplikacija pri prikazu reklame postavlja user_id = id korisnika.
   * transaction_id je jedinstven, pa ista reklama ne može da se naplati dvaput.
   */
  @Public()
  @Get('ad-callback')
  async adCallback(@Req() req: Request) {
    const raw = req.originalUrl.split('?')[1] ?? '';
    if (!(await this.ads.verify(raw))) {
      this.log.warn('Odbijen nepotpisan/neispravan poziv za nagradu reklame.');
      return { ok: false };
    }
    const q = new URLSearchParams(raw);
    const userId = q.get('user_id');
    const txId = q.get('transaction_id');
    if (!userId || !txId) return { ok: false };
    try {
      await this.tokens.change(userId, AD_REWARD, 'AD_REWARD', { externalRef: `ad:${txId}` });
    } catch (e) {
      // Ponovljen transaction_id (unique) — nagrada je već dodeljena.
      this.log.warn(`Nagrada za reklamu ${txId} nije dodeljena: ${e}`);
    }
    return { ok: true };
  }
}
