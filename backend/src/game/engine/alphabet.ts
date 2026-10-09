/**
 * Srpska azbuka — 30 slova. Љ, Њ и Џ su po jedno slovo i zauzimaju jedno polje.
 * Interno se sva slova čuvaju ćirilicom (velika slova), a latinica je samo prikaz.
 */
export const CYRILLIC_ALPHABET = [
  'А', 'Б', 'В', 'Г', 'Д', 'Ђ', 'Е', 'Ж', 'З', 'И',
  'Ј', 'К', 'Л', 'Љ', 'М', 'Н', 'Њ', 'О', 'П', 'Р',
  'С', 'Т', 'Ћ', 'У', 'Ф', 'Х', 'Ц', 'Ч', 'Џ', 'Ш',
] as const;

export type Letter = (typeof CYRILLIC_ALPHABET)[number];

export const LATIN_BY_CYRILLIC: Record<Letter, string> = {
  А: 'A', Б: 'B', В: 'V', Г: 'G', Д: 'D', Ђ: 'Đ', Е: 'E', Ж: 'Ž', З: 'Z', И: 'I',
  Ј: 'J', К: 'K', Л: 'L', Љ: 'LJ', М: 'M', Н: 'N', Њ: 'NJ', О: 'O', П: 'P', Р: 'R',
  С: 'S', Т: 'T', Ћ: 'Ć', У: 'U', Ф: 'F', Х: 'H', Ц: 'C', Ч: 'Č', Џ: 'DŽ', Ш: 'Š',
};

const LETTER_SET = new Set<string>(CYRILLIC_ALPHABET);

const CYRILLIC_BY_LATIN: Record<string, Letter> = Object.fromEntries(
  Object.entries(LATIN_BY_CYRILLIC).map(([c, l]) => [l, c as Letter]),
);

export function isLetter(value: unknown): value is Letter {
  return typeof value === 'string' && LETTER_SET.has(value);
}

/**
 * Pretvara reč (latinica ili ćirilica, bilo koja veličina slova) u ćirilicu
 * velikim slovima. Vraća null ako reč sadrži znak koji nije slovo azbuke.
 *
 * Napomena: kod latinice se "lj", "nj" i "dž" uvek tumače kao jedno slovo.
 * Za retke izuzetke (npr. "injekcija") reč treba uneti ćirilicom.
 */
export function toCyrillic(input: string): string | null {
  const s = input.trim().toUpperCase().normalize('NFC');
  if (!s) return null;
  const out: string[] = [];
  let i = 0;
  while (i < s.length) {
    const two = s.slice(i, i + 2);
    if (two === 'LJ' || two === 'NJ' || two === 'DŽ') {
      out.push(CYRILLIC_BY_LATIN[two]);
      i += 2;
      continue;
    }
    const ch = s[i];
    if (LETTER_SET.has(ch)) {
      out.push(ch);
    } else if (CYRILLIC_BY_LATIN[ch]) {
      out.push(CYRILLIC_BY_LATIN[ch]);
    } else {
      return null;
    }
    i += 1;
  }
  return out.join('');
}

export function toLatin(cyrillic: string): string {
  return Array.from(cyrillic)
    .map((ch) => (isLetter(ch) ? LATIN_BY_CYRILLIC[ch] : ch))
    .join('');
}

/** Broj slova (polja) u reči zapisanoj ćirilicom. */
export function letterCount(cyrillicWord: string): number {
  return Array.from(cyrillicWord).length;
}

/**
 * Težine za nasumična početna slova — otprilike učestalost slova u srpskom,
 * da početna slova ne bi bila uglavnom retka (Ђ, Џ, Ф...).
 */
export const LETTER_WEIGHTS: Record<Letter, number> = {
  А: 120, Б: 15, В: 35, Г: 20, Д: 35, Ђ: 3, Е: 85, Ж: 7, З: 20, И: 95,
  Ј: 40, К: 35, Л: 30, Љ: 5, М: 30, Н: 60, Њ: 5, О: 90, П: 30, Р: 50,
  С: 50, Т: 50, Ћ: 7, У: 40, Ф: 3, Х: 7, Ц: 10, Ч: 10, Џ: 1, Ш: 10,
};

export function randomWeightedLetter(rand: () => number = Math.random): Letter {
  const total = CYRILLIC_ALPHABET.reduce((s, l) => s + LETTER_WEIGHTS[l], 0);
  let r = rand() * total;
  for (const l of CYRILLIC_ALPHABET) {
    r -= LETTER_WEIGHTS[l];
    if (r < 0) return l;
  }
  return 'А';
}
