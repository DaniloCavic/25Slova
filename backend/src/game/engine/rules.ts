/** Pravila partije iz specifikacije (odeljci 6, 7.3, 9, 11). */

export const BOARD_SIZE = 5;
export const CELL_COUNT = BOARD_SIZE * BOARD_SIZE;
export const LIVES_PER_MATCH = 3;
export const MATCH_ENTRY_COST = 10;
export const DAILY_REWARD = 30;
export const AD_REWARD = 5;
export const LOSS_PENALTY = 10;

/**
 * Poeni se u bazi čuvaju u stotim delovima (kao novac u parama), da bi dve decimale
 * uvek bile tačne: 36,11 poena = 3611. Sve funkcije ispod sa "Cents" rade sa stotinkama.
 */
export const POINTS_SCALE = 100;
export const LOSS_PENALTY_CENTS = LOSS_PENALTY * POINTS_SCALE;
/** Pobeda zato što je protivnik predao ili izgubio sva tri života: fiksno 25 poena. */
export const FORFEIT_WIN_CENTS = 25 * POINTS_SCALE;
export const toPoints = (cents: number) => cents / POINTS_SCALE;
export const toCents = (points: number) => Math.round(points * POINTS_SCALE);
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
 * Nagrada pobedniku: (poeni × broj validnih reči) ÷ 7,2, na dve decimale (u stotinkama).
 * Maksimum: 60 × 12 ÷ 7,2 = 100,00.
 */
export function winRewardCents(points: number, words: number): number {
  return Math.round((points * words * POINTS_SCALE) / 7.2);
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
  // Level se završava na …00, a sledeći počinje od …01 (npr. Level 2: 101–500).
  return { level, min, max: next === null ? null : next - 1, next };
}

export const levelForCents = (cents: number) => levelForPoints(toPoints(cents));

/** Tabela levela za prikaz igračima. */
export function levelTable() {
  return [...LEVEL_THRESHOLDS].reverse().reduce<{ level: number; from: number; to: number | null }[]>(
    (acc, t, i, arr) => {
      if (i === 0) acc.push({ level: 1, from: 0, to: t.min - 1 });
      acc.push({ level: t.level, from: t.min, to: arr[i + 1] ? arr[i + 1].min - 1 : null });
      return acc;
    },
    [],
  );
}
