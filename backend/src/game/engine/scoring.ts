import { BOARD_SIZE, MAX_WORD_LENGTH, MIN_WORD_LENGTH } from './rules';

export type Cell = string | null;
export type Board = Cell[]; // 25 polja, red po red

export type LineKind = 'ROW' | 'COL' | 'DIAG';

export interface LineResult {
  kind: LineKind;
  index: number; // broj reda/kolone; dijagonala 0 = ↘, 1 = ↙
  cells: number[]; // indeksi polja u nizu
  points: number;
  word: string | null; // najduža validna reč (ćirilica)
  wordCells: number[]; // polja koja čine reč, redom čitanja
}

export interface BoardScore {
  points: number;
  wordsCount: number;
  lines: LineResult[];
}

/** 5 redova + 5 kolona + 2 glavne dijagonale = 12 nizova. */
export const LINES: { kind: LineKind; index: number; cells: number[] }[] = (() => {
  const lines: { kind: LineKind; index: number; cells: number[] }[] = [];
  for (let r = 0; r < BOARD_SIZE; r++) {
    lines.push({ kind: 'ROW', index: r, cells: [...Array(BOARD_SIZE)].map((_, c) => r * BOARD_SIZE + c) });
  }
  for (let c = 0; c < BOARD_SIZE; c++) {
    lines.push({ kind: 'COL', index: c, cells: [...Array(BOARD_SIZE)].map((_, r) => r * BOARD_SIZE + c) });
  }
  lines.push({ kind: 'DIAG', index: 0, cells: [...Array(BOARD_SIZE)].map((_, i) => i * BOARD_SIZE + i) });
  lines.push({
    kind: 'DIAG',
    index: 1,
    cells: [...Array(BOARD_SIZE)].map((_, i) => i * BOARD_SIZE + (BOARD_SIZE - 1 - i)),
  });
  return lines;
})();

/**
 * Najduža validna reč u nizu, čitano u oba smera.
 * Kraće reči unutar duže se ne sabiraju — niz donosi samo dužinu najduže.
 */
export function scoreLine(board: Board, cells: number[], isWord: (w: string) => boolean) {
  const directions = [cells, [...cells].reverse()];
  for (let len = Math.min(MAX_WORD_LENGTH, cells.length); len >= MIN_WORD_LENGTH; len--) {
    for (const dir of directions) {
      for (let start = 0; start + len <= dir.length; start++) {
        const slice = dir.slice(start, start + len);
        const letters = slice.map((i) => board[i]);
        if (letters.some((l) => !l)) continue;
        const word = letters.join('');
        if (isWord(word)) {
          return { points: len, word, wordCells: slice };
        }
      }
    }
  }
  return { points: 0, word: null, wordCells: [] as number[] };
}

export function scoreBoard(board: Board, isWord: (w: string) => boolean): BoardScore {
  const lines = LINES.map((line) => ({ ...line, ...scoreLine(board, line.cells, isWord) }));
  return {
    points: lines.reduce((s, l) => s + l.points, 0),
    wordsCount: lines.filter((l) => l.points > 0).length,
    lines,
  };
}
