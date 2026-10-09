import { Controller, Get } from '@nestjs/common';
import { Public } from './common/auth.guard';
import { CYRILLIC_ALPHABET, LATIN_BY_CYRILLIC } from './game/engine/alphabet';
import { MATCH_TYPES, MATCH_ENTRY_COST, DAILY_REWARD, AD_REWARD, LIVES_PER_MATCH } from './game/engine/rules';

@Controller()
export class HealthController {
  @Public()
  @Get('health')
  health() {
    return { ok: true, time: new Date().toISOString() };
  }

  /** Pravila i azbuka za aplikaciju — da se brojevi ne bi duplirali u klijentu. */
  @Public()
  @Get('config')
  config() {
    return {
      alphabet: CYRILLIC_ALPHABET.map((c) => ({ cyrillic: c, latin: LATIN_BY_CYRILLIC[c] })),
      matchTypes: MATCH_TYPES,
      matchEntryCost: MATCH_ENTRY_COST,
      dailyReward: DAILY_REWARD,
      adReward: AD_REWARD,
      lives: LIVES_PER_MATCH,
    };
  }
}
