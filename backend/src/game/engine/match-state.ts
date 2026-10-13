import { isLetter, Letter, randomWeightedLetter } from './alphabet';
import { CELL_COUNT, LIVES_PER_MATCH, MATCH_TYPES, MatchType, winRewardCents, LOSS_PENALTY_CENTS } from './rules';
import { Board, BoardScore, scoreBoard } from './scoring';

export type Seat = 0 | 1;
export type Phase = 'CHOOSE' | 'FOLLOW' | 'ENDED';
export type EndReason = 'BOARDS_FULL' | 'LIVES_LOST' | 'RESIGNED';

export interface Move {
  seat: Seat;
  letter: Letter;
  cell: number;
  chosen: boolean; // true = igrač je izabrao slovo, false = postavio protivnikovo
  at: number;
}

export interface MatchState {
  type: MatchType;
  turnSeconds: number;
  boards: [Board, Board];
  initialCells: { cell: number; letter: Letter }[];
  lives: [number, number];
  phase: Phase;
  /** Igrač koji sada treba da odigra. */
  actor: Seat;
  /** Slovo koje drugi igrač treba da postavi (faza FOLLOW). */
  currentLetter: Letter | null;
  /** Rok za potez (epoch ms) — određuje server. */
  deadline: number;
  moves: Move[];
  endReason?: EndReason;
  /** Gubitnik kod LIVES_LOST/RESIGNED. */
  forfeitedBy?: Seat;
}

export class MoveError extends Error {}

export function other(seat: Seat): Seat {
  return seat === 0 ? 1 : 0;
}

export function createMatchState(
  type: MatchType,
  now: number,
  rand: () => number = Math.random,
): MatchState {
  const { initialLetters, turnSeconds } = MATCH_TYPES[type];
  const free = [...Array(CELL_COUNT).keys()];
  const initialCells: { cell: number; letter: Letter }[] = [];
  for (let i = 0; i < initialLetters; i++) {
    const idx = Math.floor(rand() * free.length);
    const cell = free.splice(idx, 1)[0];
    initialCells.push({ cell, letter: randomWeightedLetter(rand) });
  }
  // Ista početna slova na istim poljima za oba igrača — fer start.
  const makeBoard = (): Board => {
    const b: Board = Array(CELL_COUNT).fill(null);
    for (const ic of initialCells) b[ic.cell] = ic.letter;
    return b;
  };
  const firstChooser: Seat = rand() < 0.5 ? 0 : 1;
  return {
    type,
    turnSeconds,
    boards: [makeBoard(), makeBoard()],
    initialCells,
    lives: [LIVES_PER_MATCH, LIVES_PER_MATCH],
    phase: 'CHOOSE',
    actor: firstChooser,
    currentLetter: null,
    deadline: now + turnSeconds * 1000,
    moves: [],
  };
}

function assertCellFree(board: Board, cell: number) {
  if (!Number.isInteger(cell) || cell < 0 || cell >= CELL_COUNT) {
    throw new MoveError('Nepostojeće polje.');
  }
  if (board[cell] !== null) {
    throw new MoveError('Polje je već zauzeto.');
  }
}

function isFull(board: Board) {
  return board.every((c) => c !== null);
}

/**
 * Potez igrača. U fazi CHOOSE igrač bira slovo i polje; u fazi FOLLOW
 * postavlja slovo koje je izabrao protivnik (parametar letter se ignoriše).
 */
export function applyMove(
  state: MatchState,
  seat: Seat,
  cell: number,
  letter: string | null,
  now: number,
): MatchState {
  if (state.phase === 'ENDED') throw new MoveError('Partija je završena.');
  if (state.actor !== seat) throw new MoveError('Nije vaš potez.');
  if (now > state.deadline) throw new MoveError('Vreme za potez je isteklo.');

  const s: MatchState = structuredClone(state);
  const board = s.boards[seat];
  assertCellFree(board, cell);

  if (s.phase === 'CHOOSE') {
    if (!isLetter(letter)) throw new MoveError('Nepoznato slovo.');
    board[cell] = letter;
    s.moves.push({ seat, letter, cell, chosen: true, at: now });
    s.phase = 'FOLLOW';
    s.currentLetter = letter;
    s.actor = other(seat);
  } else {
    const l = s.currentLetter as Letter;
    board[cell] = l;
    s.moves.push({ seat, letter: l, cell, chosen: false, at: now });
    s.currentLetter = null;
    if (isFull(s.boards[0]) && isFull(s.boards[1])) {
      s.phase = 'ENDED';
      s.endReason = 'BOARDS_FULL';
      return s;
    }
    // Igrač koji je upravo postavio slovo bira sledeće.
    s.phase = 'CHOOSE';
    s.actor = seat;
  }
  s.deadline = now + s.turnSeconds * 1000;
  return s;
}

/**
 * Istek vremena: igrač na potezu gubi život i dobija novo odbrojavanje za isti potez.
 * Gubitak sva tri života znači poraz.
 */
export function applyTimeout(state: MatchState, now: number): MatchState {
  if (state.phase === 'ENDED' || now < state.deadline) return state;
  const s: MatchState = structuredClone(state);
  s.lives[s.actor] -= 1;
  if (s.lives[s.actor] <= 0) {
    s.lives[s.actor] = 0;
    s.phase = 'ENDED';
    s.endReason = 'LIVES_LOST';
    s.forfeitedBy = s.actor;
    return s;
  }
  s.deadline = state.deadline + s.turnSeconds * 1000;
  return s;
}

export function applyResign(state: MatchState, seat: Seat): MatchState {
  if (state.phase === 'ENDED') throw new MoveError('Partija je završena.');
  const s: MatchState = structuredClone(state);
  s.phase = 'ENDED';
  s.endReason = 'RESIGNED';
  s.forfeitedBy = seat;
  return s;
}

export interface MatchResult {
  scores: [BoardScore, BoardScore];
  winner: Seat | null; // null = nerešeno
  /** Promena salda u stotinkama poena (3611 = +36,11). */
  pointsDelta: [number, number];
}

/**
 * Pobednik: više poena → više validnih reči → nerešeno.
 * Kod predaje ili gubitka života pobeđuje protivnik.
 */
export function computeResult(state: MatchState, isWord: (w: string) => boolean): MatchResult {
  const scores: [BoardScore, BoardScore] = [
    scoreBoard(state.boards[0], isWord),
    scoreBoard(state.boards[1], isWord),
  ];
  let winner: Seat | null;
  if (state.forfeitedBy !== undefined) {
    winner = other(state.forfeitedBy);
  } else if (scores[0].points !== scores[1].points) {
    winner = scores[0].points > scores[1].points ? 0 : 1;
  } else if (scores[0].wordsCount !== scores[1].wordsCount) {
    winner = scores[0].wordsCount > scores[1].wordsCount ? 0 : 1;
  } else {
    winner = null;
  }
  const pointsDelta: [number, number] = [0, 0];
  if (winner !== null) {
    const w = scores[winner];
    pointsDelta[winner] = winRewardCents(w.points, w.wordsCount);
    pointsDelta[other(winner)] = -LOSS_PENALTY_CENTS;
  }
  return { scores, winner, pointsDelta };
}
