/** Pravila partije iz specifikacije (odeljci 6, 7.3, 9, 11). */

export const BOARD_SIZE = 5;
export const CELL_COUNT = BOARD_SIZE * BOARD_SIZE;
export const LIVES_PER_MATCH = 3;
export const MATCH_ENTRY_COST = 10;
export const DAILY_REWARD = 30;
export const AD_REWARD = 5;
export const LOSS_PENALTY = 10;
export const MIN_WORD_LENGTH = 2;
export const MAX_WORD_LENGTH = 5;

export type MatchType = 1 | 2 | 3;

export const MATCH_TYPES: Record<MatchType, { initialLetters: number; turnSeconds: number }> = {
  1: { initialLetters: 1, turnSeconds: 30 },
  2: { initialLetters: 3, turnSeconds: 45 },
  3: { initialLetters: 5, turnSeconds: 60 },
};

export function randomMatchType(rand: () => number = Math.random): MatchType {
  return (Math.floor(rand() * 3) + 1) as MatchType;
}

/**
 * Nagrada pobedniku: (poeni × broj validnih reči) ÷ 7,2, zaokruženo na ceo broj.
 * Maksimum: 60 × 12 ÷ 7,2 = 100.
 */
export function winReward(points: number, words: number): number {
  return Math.round((points * words) / 7.2);
}

/** Leveli prema ukupnom saldu poena (odeljak 6.2). */
const LEVEL_THRESHOLDS = [
  { level: 10, min: 500_001 },
  { level: 9, min: 200_001 },
  { level: 8, min: 100_001 },
  { level: 7, min: 50_001 },
  { level: 6, min: 15_001 },
  { level: 5, min: 5_001 },
  { level: 4, min: 2_001 },
  { level: 3, min: 501 },
  { level: 2, min: 101 },
];

export function levelForPoints(totalPoints: number): number {
  for (const t of LEVEL_THRESHOLDS) {
    if (totalPoints >= t.min) return t.level;
  }
  return 1;
}

/** Napredak ka sledećem levelu: od koliko poena počinje trenutni i sledeći level. */
export function levelProgress(totalPoints: number) {
  const level = levelForPoints(totalPoints);
  const min = level === 1 ? 0 : LEVEL_THRESHOLDS.find((t) => t.level === level)!.min;
  const next = LEVEL_THRESHOLDS.find((t) => t.level === level + 1)?.min ?? null;
  return { level, min, next };
}
