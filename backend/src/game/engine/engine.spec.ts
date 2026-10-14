import { toCyrillic, toLatin, letterCount } from './alphabet';
import { levelForPoints, levelTable, winRewardCents } from './rules';
import { scoreBoard, scoreLine, LINES, Board } from './scoring';
import {
  applyMove,
  applyResign,
  applyTimeout,
  computeResult,
  createMatchState,
  MoveError,
  MatchState,
} from './match-state';

const dict = new Set(['РОГ', 'СТРОГ', 'ГОР', 'ОР', 'ЉУТ', 'ЊИВА', 'ЏАК', 'КУЋА', 'АС', 'ТО']);
const isWord = (w: string) => dict.has(w);

function boardFromRows(rows: string[]): Board {
  // Svaki red je niz od 5 slova; '.' = prazno; ćirilica.
  return rows.flatMap((r) => Array.from(r).map((ch) => (ch === '.' ? null : ch)));
}

describe('azbuka', () => {
  it('pretvara latinicu u ćirilicu uz Lj/Nj/Dž kao jedno slovo', () => {
    expect(toCyrillic('ljut')).toBe('ЉУТ');
    expect(toCyrillic('Njiva')).toBe('ЊИВА');
    expect(toCyrillic('džak')).toBe('ЏАК');
    expect(toCyrillic('kuća')).toBe('КУЋА');
    expect(toCyrillic('КУЋА')).toBe('КУЋА');
    expect(toCyrillic('ljut1')).toBeNull();
    expect(toCyrillic('quiz')).toBeNull();
  });
  it('broji Љ, Њ, Џ kao po jedno polje', () => {
    expect(letterCount('ЉУТ')).toBe(3);
    expect(letterCount('ЏАК')).toBe(3);
    expect(toLatin('ЊИВА')).toBe('NJIVA');
  });
});

describe('pravila', () => {
  it('leveli prema ukupnom saldu', () => {
    expect(levelForPoints(-50)).toBe(1);
    expect(levelForPoints(100)).toBe(1);
    expect(levelForPoints(101)).toBe(2);
    expect(levelForPoints(500)).toBe(2);
    expect(levelForPoints(501)).toBe(3);
    expect(levelForPoints(5_001)).toBe(5);
    expect(levelForPoints(500_000)).toBe(9);
    expect(levelForPoints(500_001)).toBe(10);
  });
  it('nagrada pobedniku = poeni × reči ÷ 7,2, na dve decimale (u stotinkama)', () => {
    expect(winRewardCents(60, 12)).toBe(10000);
    expect(winRewardCents(36, 10)).toBe(5000);
    expect(winRewardCents(37, 11)).toBe(5653); // 56,527… → 56,53
    expect(winRewardCents(13, 5)).toBe(903); // 9,027… → 9,03
    expect(winRewardCents(0, 0)).toBe(0);
  });
  it('tabela levela: svaki level se završava na …00, sledeći počinje od …01', () => {
    const t = levelTable();
    expect(t[0]).toEqual({ level: 1, from: 0, to: 100 });
    expect(t[1]).toEqual({ level: 2, from: 101, to: 500 });
    expect(t[2]).toEqual({ level: 3, from: 501, to: 2000 });
    expect(t[9]).toEqual({ level: 10, from: 500001, to: null });
  });
});

describe('bodovanje', () => {
  it('ima tačno 12 nizova', () => {
    expect(LINES).toHaveLength(12);
  });
  it('OROGT donosi 3 poena (ROG), kraće reči se ne sabiraju', () => {
    const b = boardFromRows(['ОРОГТ', '.....', '.....', '.....', '.....']);
    const r = scoreLine(b, LINES[0].cells, isWord);
    expect(r.points).toBe(3);
    expect(r.word).toBe('РОГ');
  });
  it('GORTS donosi 5 poena čitanjem unazad (STROG)', () => {
    const b = boardFromRows(['ГОРТС', '.....', '.....', '.....', '.....']);
    const r = scoreLine(b, LINES[0].cells, isWord);
    expect(r.points).toBe(5);
    expect(r.word).toBe('СТРОГ');
  });
  it('niz bez reči donosi 0, maksimum 5 po nizu', () => {
    const b = boardFromRows(['ШШШШШ', 'ШШШШШ', 'ШШШШШ', 'ШШШШШ', 'ШШШШШ']);
    expect(scoreBoard(b, isWord)).toMatchObject({ points: 0, wordsCount: 0 });
  });
  it('broji kolone i dijagonale; Љ je jedno polje', () => {
    const b = boardFromRows(['Љ.ШШК', 'УШШШУ', 'ТШШШЋ', 'ШШШША', 'ШШШШШ']);
    const s = scoreBoard(b, isWord);
    const col0 = s.lines.find((l) => l.kind === 'COL' && l.index === 0)!;
    const col4 = s.lines.find((l) => l.kind === 'COL' && l.index === 4)!;
    expect(col0.word).toBe('ЉУТ');
    expect(col4.word).toBe('КУЋА');
    expect(s.points).toBe(7);
    expect(s.wordsCount).toBe(2);
  });
  it('prazna polja prekidaju reč', () => {
    const b = boardFromRows(['СТ.ОР', '.....', '.....', '.....', '.....']);
    const r = scoreLine(b, LINES[0].cells, isWord);
    expect(r.word).toBe('ОР'); // СТРОГ ne može da se pročita preko praznog polja
    expect(r.points).toBe(2);
  });
});

describe('tok partije', () => {
  const seq = (vals: number[]) => {
    let i = 0;
    return () => vals[i++ % vals.length];
  };

  it('postavlja 1/3/5 početnih slova na ista polja na obe table', () => {
    for (const [type, n] of [[1, 1], [2, 3], [3, 5]] as const) {
      const s = createMatchState(type, 0);
      expect(s.initialCells).toHaveLength(n);
      expect(s.boards[0]).toEqual(s.boards[1]);
      expect(s.boards[0].filter(Boolean)).toHaveLength(n);
      expect(s.turnSeconds).toBe({ 1: 30, 2: 45, 3: 60 }[type]);
    }
  });

  it('oba igrača dobijaju isto slovo, a izbor slova se smenjuje', () => {
    let s = createMatchState(1, 0, seq([0.0, 0.1, 0.9]));
    const first = s.actor;
    const second = first === 0 ? 1 : 0;
    const free0 = s.boards[first].findIndex((c) => c === null);
    s = applyMove(s, first, free0, 'А', 1000);
    expect(s.phase).toBe('FOLLOW');
    expect(s.actor).toBe(second);
    expect(s.currentLetter).toBe('А');
    const free1 = s.boards[second].lastIndexOf(null);
    s = applyMove(s, second, free1, 'Ш', 2000); // slovo se ignoriše
    expect(s.boards[second][free1]).toBe('А');
    expect(s.phase).toBe('CHOOSE');
    expect(s.actor).toBe(second);
  });

  it('ne dozvoljava zauzeto polje ni tuđi potez', () => {
    const s = createMatchState(1, 0);
    const taken = s.initialCells[0].cell;
    expect(() => applyMove(s, s.actor, taken, 'А', 1)).toThrow(MoveError);
    const notActor = s.actor === 0 ? 1 : 0;
    expect(() => applyMove(s, notActor, 0, 'А', 1)).toThrow(MoveError);
    const free = s.boards[0].findIndex((c) => c === null);
    expect(() => applyMove(s, s.actor, free, 'Q', 1)).toThrow(MoveError);
  });

  it('istek vremena oduzima jedan život, treći znači poraz', () => {
    let s: MatchState = createMatchState(1, 0);
    const a = s.actor;
    s = applyTimeout(s, 29_999);
    expect(s.lives[a]).toBe(3);
    s = applyTimeout(s, 30_000);
    expect(s.lives[a]).toBe(2);
    expect(s.deadline).toBe(60_000);
    s = applyTimeout(s, 60_000);
    s = applyTimeout(s, 90_000);
    expect(s.lives[a]).toBe(0);
    expect(s.phase).toBe('ENDED');
    expect(s.endReason).toBe('LIVES_LOST');
    const res = computeResult(s, isWord);
    expect(res.winner).toBe(a === 0 ? 1 : 0);
    expect(res.pointsDelta[a]).toBe(-1000);
    expect(res.pointsDelta[a === 0 ? 1 : 0]).toBe(2500); // fiksno 25 poena
  });

  it('partija se završava kad se obe table popune', () => {
    let s = createMatchState(3, 0);
    let t = 0;
    while (s.phase !== 'ENDED') {
      const free = s.boards[s.actor].findIndex((c) => c === null);
      s = applyMove(s, s.actor, free, 'О', (t += 100));
    }
    expect(s.endReason).toBe('BOARDS_FULL');
    expect(s.boards[0].every(Boolean) && s.boards[1].every(Boolean)).toBe(true);
    expect(s.moves).toHaveLength(2 * 20);
  });

  it('izjednačenje: poeni, pa broj reči, pa nerešeno', () => {
    const base = createMatchState(1, 0);
    const mk = (b0: string[], b1: string[]): MatchState => ({
      ...base,
      phase: 'ENDED',
      endReason: 'BOARDS_FULL',
      boards: [boardFromRows(b0), boardFromRows(b1)],
    });
    const empty = ['ШШШШШ', 'ШШШШШ', 'ШШШШШ', 'ШШШШШ', 'ШШШШШ'];
    // 4 poena jednom rečju protiv 4 poena sa dve reči (2+2) -> pobeđuje drugi
    const r1 = computeResult(
      mk(['КУЋАШ', ...empty.slice(1)], ['АСШШШ', 'ТОШШШ', ...empty.slice(2)]),
      isWord,
    );
    expect(r1.scores[0].points).toBe(r1.scores[1].points);
    expect(r1.winner).toBe(1);
    const r2 = computeResult(mk(empty, empty), isWord);
    expect(r2.winner).toBeNull();
    expect(r2.pointsDelta).toEqual([0, 0]);
  });

  it('predaja daje pobedu protivniku', () => {
    const s = applyResign(createMatchState(2, 0), 1);
    const r = computeResult(s, isWord);
    expect(r.winner).toBe(0);
    expect(r.pointsDelta).toEqual([2500, -1000]);
  });
});

describe('napredak levela', () => {
  it('vraća granice trenutnog i sledećeg levela', () => {
    const { levelProgress } = jest.requireActual('./rules');
    expect(levelProgress(295)).toEqual({ level: 2, min: 101, max: 500, next: 501 });
    expect(levelProgress(0)).toEqual({ level: 1, min: 0, max: 100, next: 101 });
    expect(levelProgress(600_000)).toEqual({ level: 10, min: 500_001, max: null, next: null });
  });
});
