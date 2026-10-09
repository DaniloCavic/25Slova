/**
 * Uvoz početnog rečnika:  npm run seed
 * Može se pokrenuti više puta — postojeće reči se preskaču.
 */
import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';
import * as path from 'path';
import { letterCount, toCyrillic } from '../src/game/engine/alphabet';
import { MAX_WORD_LENGTH, MIN_WORD_LENGTH } from '../src/game/engine/rules';

async function main() {
  const prisma = new PrismaClient();
  const file = process.argv[2] || path.join(__dirname, 'seed', 'words-sr.txt');
  const text = fs
    .readFileSync(file, 'utf8')
    .split('\n')
    .filter((l) => !l.trim().startsWith('#'))
    .join(' ');
  const words = new Set<string>();
  const rejected: string[] = [];
  for (const raw of text.split(/[\s,;]+/).filter(Boolean)) {
    const w = toCyrillic(raw);
    const n = w ? letterCount(w) : 0;
    if (!w || n < MIN_WORD_LENGTH || n > MAX_WORD_LENGTH) rejected.push(raw);
    else words.add(w);
  }
  const res = await prisma.word.createMany({
    data: [...words].map((w) => ({ word: w, length: letterCount(w) })),
    skipDuplicates: true,
  });
  console.log(`Uvezeno ${res.count} novih reči (ukupno u fajlu: ${words.size}).`);
  if (rejected.length) console.log(`Preskočeno (nisu 2–5 slova ili imaju nepoznat znak): ${rejected.join(', ')}`);
  await prisma.$disconnect();
}

void main();
