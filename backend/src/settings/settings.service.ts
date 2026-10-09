import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface MatchmakingSettings {
  /** Početni dozvoljeni razmak u levelima (1 → Level 5 igra sa 4–6). */
  initialLevelRange: number;
  /** Na koliko sekundi čekanja se raspon proširuje za 1 level. */
  expandEverySeconds: number;
  /** Najveći razmak (9 = bilo ko). */
  maxLevelRange: number;
  /** Koliko minuta važi kod privatne partije. */
  privateCodeMinutes: number;
}

export const DEFAULT_MATCHMAKING: MatchmakingSettings = {
  initialLevelRange: 1,
  expandEverySeconds: 10,
  maxLevelRange: 9,
  privateCodeMinutes: 10,
};

/** Podešavanja koja admin menja bez novog izdanja aplikacije. */
@Injectable()
export class SettingsService {
  private cache: MatchmakingSettings = { ...DEFAULT_MATCHMAKING };

  constructor(private readonly prisma: PrismaService) {}

  async load() {
    const row = await this.prisma.setting.findUnique({ where: { key: 'matchmaking' } });
    this.cache = { ...DEFAULT_MATCHMAKING, ...((row?.value as object) ?? {}) };
    return this.cache;
  }

  get matchmaking(): MatchmakingSettings {
    return this.cache;
  }

  async updateMatchmaking(patch: Partial<MatchmakingSettings>) {
    const next = { ...this.cache };
    for (const k of Object.keys(DEFAULT_MATCHMAKING) as (keyof MatchmakingSettings)[]) {
      const v = patch[k];
      if (typeof v === 'number' && Number.isFinite(v) && v >= 0) next[k] = Math.round(v);
    }
    next.expandEverySeconds = Math.max(1, next.expandEverySeconds);
    next.privateCodeMinutes = Math.max(1, next.privateCodeMinutes);
    await this.prisma.setting.upsert({
      where: { key: 'matchmaking' },
      create: { key: 'matchmaking', value: next as unknown as Prisma.InputJsonValue },
      update: { value: next as unknown as Prisma.InputJsonValue },
    });
    this.cache = next;
    return next;
  }
}
