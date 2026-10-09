import { BadRequestException, ConflictException, Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { letterCount, toCyrillic, toLatin } from '../game/engine/alphabet';
import { MAX_WORD_LENGTH, MIN_WORD_LENGTH } from '../game/engine/rules';

export interface ParsedWord {
  input: string;
  word?: string;
  error?: string;
}

/**
 * Odobreni rečnik igre. Sve reči su u memoriji (Set) radi trenutne provere table;
 * baza je izvor istine, a izmene administratora se odmah primenjuju i u memoriji.
 * Za igru su važne samo reči od 2 do 5 slova.
 */
@Injectable()
export class DictionaryService implements OnModuleInit {
  private readonly log = new Logger(DictionaryService.name);
  private words = new Set<string>();

  async onModuleInit() {
    await this.reload();
  }

  async reload() {
    const rows = await this.prisma.word.findMany({ select: { word: true } });
    this.words = new Set(rows.map((r) => r.word));
    this.log.log(`Rečnik učitan: ${this.words.size} reči.`);
  }

  constructor(private readonly prisma: PrismaService) {}

  has = (word: string) => this.words.has(word);

  get size() {
    return this.words.size;
  }

  parse(input: string): ParsedWord {
    const word = toCyrillic(input);
    if (!word) return { input, error: 'Sadrži znak koji nije slovo srpske azbuke.' };
    const n = letterCount(word);
    if (n < MIN_WORD_LENGTH || n > MAX_WORD_LENGTH) {
      return { input, error: `Reč mora imati od ${MIN_WORD_LENGTH} do ${MAX_WORD_LENGTH} slova (ima ${n}).` };
    }
    return { input, word };
  }

  async add(input: string, adminId?: string) {
    const p = this.parse(input);
    if (!p.word) throw new BadRequestException(p.error);
    try {
      const row = await this.prisma.word.create({
        data: { word: p.word, length: letterCount(p.word), addedById: adminId },
      });
      this.words.add(row.word);
      return this.view(row);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Reč već postoji u rečniku.');
      }
      throw e;
    }
  }

  /** Masovni uvoz: jedna reč po redu (ili razdvojene zarezom/razmakom). */
  async bulkAdd(text: string, adminId?: string) {
    const inputs = text
      .split(/[\s,;]+/)
      .map((s) => s.trim())
      .filter(Boolean);
    const parsed = inputs.map((i) => this.parse(i));
    const valid = [...new Set(parsed.filter((p) => p.word).map((p) => p.word!))];
    const res = await this.prisma.word.createMany({
      data: valid.map((w) => ({ word: w, length: letterCount(w), addedById: adminId })),
      skipDuplicates: true,
    });
    valid.forEach((w) => this.words.add(w));
    return {
      added: res.count,
      duplicates: valid.length - res.count,
      invalid: parsed.filter((p) => p.error).map((p) => ({ input: p.input, error: p.error })),
    };
  }

  async update(id: string, input: string) {
    const p = this.parse(input);
    if (!p.word) throw new BadRequestException(p.error);
    const old = await this.prisma.word.findUnique({ where: { id } });
    if (!old) throw new NotFoundException('Reč ne postoji.');
    try {
      const row = await this.prisma.word.update({
        where: { id },
        data: { word: p.word, length: letterCount(p.word) },
      });
      this.words.delete(old.word);
      this.words.add(row.word);
      return this.view(row);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Reč već postoji u rečniku.');
      }
      throw e;
    }
  }

  async remove(id: string) {
    const row = await this.prisma.word.delete({ where: { id } }).catch(() => null);
    if (!row) throw new NotFoundException('Reč ne postoji.');
    this.words.delete(row.word);
    return { ok: true };
  }

  async list(q: { search?: string; length?: number; page?: number; pageSize?: number }) {
    const page = Math.max(1, q.page || 1);
    const pageSize = Math.min(200, Math.max(1, q.pageSize || 50));
    const where: Prisma.WordWhereInput = {};
    if (q.search) {
      const cyr = toCyrillic(q.search) ?? q.search.toUpperCase();
      where.word = { contains: cyr };
    }
    if (q.length) where.length = q.length;
    const [total, rows] = await Promise.all([
      this.prisma.word.count({ where }),
      this.prisma.word.findMany({
        where,
        orderBy: { word: 'asc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: { addedBy: { select: { username: true } } },
      }),
    ]);
    return { total, page, pageSize, items: rows.map((r) => ({ ...this.view(r), addedBy: r.addedBy?.username ?? null })) };
  }

  /** Provera jedne reči (za admin panel i testiranje rečnika). */
  check(input: string) {
    const p = this.parse(input);
    return { ...p, latin: p.word ? toLatin(p.word) : null, inDictionary: p.word ? this.has(p.word) : false };
  }

  private view(r: { id: string; word: string; length: number; createdAt: Date }) {
    return { id: r.id, word: r.word, latin: toLatin(r.word), length: r.length, createdAt: r.createdAt };
  }
}
