import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, SuggestionStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PushService } from '../push/push.service';
import { letterCount, toLatin } from '../game/engine/alphabet';
import { DictionaryService } from './dictionary.service';

/** Koliko predloga jedan igrač može da ima na čekanju u isto vreme. */
const MAX_PENDING = 20;

/**
 * Predlozi reči od igrača: igrač predloži reč koje nema u rečniku, admin je prihvati
 * (reč odmah ulazi u rečnik) ili odbije. Obe strane dobijaju obaveštenje.
 */
@Injectable()
export class SuggestionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly dict: DictionaryService,
    private readonly push: PushService,
  ) {}

  async suggest(userId: string, input: string, note?: string) {
    const p = this.dict.parse((input || '').trim());
    if (!p.word) throw new BadRequestException(p.error);
    if (this.dict.has(p.word)) throw new ConflictException('Ova reč je već u rečniku.');
    const mine = await this.prisma.wordSuggestion.findUnique({ where: { userId_word: { userId, word: p.word } } });
    if (mine) {
      throw new ConflictException(
        mine.status === 'REJECTED' ? 'Ovu reč ste već predložili i odbijena je.' : 'Ovu reč ste već predložili.',
      );
    }
    const pending = await this.prisma.wordSuggestion.count({ where: { userId, status: 'PENDING' } });
    if (pending >= MAX_PENDING) {
      throw new BadRequestException(`Imate ${MAX_PENDING} predloga na čekanju. Sačekajte da ih admin pregleda.`);
    }
    const row = await this.prisma.wordSuggestion.create({
      data: { userId, word: p.word, length: letterCount(p.word), note: note?.trim().slice(0, 200) || null },
      include: { user: { select: { username: true } } },
    });
    void this.notifyAdmins(row.word, row.user.username);
    return this.view(row);
  }

  async mine(userId: string) {
    const rows = await this.prisma.wordSuggestion.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((r) => this.view(r));
  }

  /** Admin: predlozi po statusu, sa brojem igrača koji su predložili istu reč. */
  async list(status: SuggestionStatus = 'PENDING') {
    const rows = await this.prisma.wordSuggestion.findMany({
      where: { status },
      orderBy: { createdAt: status === 'PENDING' ? 'asc' : 'desc' },
      take: 500,
      include: { user: { select: { username: true } } },
    });
    const counts = await this.prisma.wordSuggestion.groupBy({
      by: ['word'],
      where: { word: { in: [...new Set(rows.map((r) => r.word))] }, status },
      _count: { _all: true },
    });
    const byWord = new Map(counts.map((c) => [c.word, c._count._all]));
    // Ista reč od više igrača se prikazuje jednom.
    const seen = new Map<string, ReturnType<SuggestionsService['view']> & { users: string[]; count: number }>();
    for (const r of rows) {
      const cur = seen.get(r.word);
      if (cur) {
        cur.users.push(r.user.username);
        if (!cur.note && r.note) cur.note = r.note;
      } else {
        seen.set(r.word, { ...this.view(r), users: [r.user.username], count: byWord.get(r.word) ?? 1 });
      }
    }
    return [...seen.values()];
  }

  pendingCount() {
    return this.prisma.wordSuggestion
      .groupBy({ by: ['word'], where: { status: 'PENDING' } })
      .then((g) => ({ pending: g.length }));
  }

  /** Prihvatanje: reč ulazi u rečnik, svi predlozi iste reči su prihvaćeni, igrači dobijaju obaveštenje. */
  async accept(id: string, adminId: string) {
    const s = await this.prisma.wordSuggestion.findUnique({ where: { id } });
    if (!s) throw new NotFoundException('Predlog ne postoji.');
    if (!this.dict.has(s.word)) {
      await this.dict.add(s.word, adminId).catch((e) => {
        if (!(e instanceof ConflictException)) throw e;
      });
    }
    return this.decide(s.word, 'ACCEPTED');
  }

  async reject(id: string, reason?: string) {
    const s = await this.prisma.wordSuggestion.findUnique({ where: { id } });
    if (!s) throw new NotFoundException('Predlog ne postoji.');
    return this.decide(s.word, 'REJECTED', reason);
  }

  private async decide(word: string, status: 'ACCEPTED' | 'REJECTED', reason?: string) {
    const pending = await this.prisma.wordSuggestion.findMany({ where: { word, status: 'PENDING' } });
    await this.prisma.wordSuggestion.updateMany({
      where: { word, status: 'PENDING' },
      data: { status, decidedAt: new Date(), reason: reason?.trim().slice(0, 200) || null },
    });
    const latin = toLatin(word).toUpperCase();
    for (const s of pending) {
      void this.push.send(
        s.userId,
        status === 'ACCEPTED'
          ? { title: 'Reč je dodata u rečnik! 📖', body: `Tvoj predlog „${latin}“ je prihvaćen. Hvala!`, tag: `sug-${word}` }
          : {
              title: 'Predlog reči',
              body: `Reč „${latin}“ nije dodata u rečnik${reason?.trim() ? `: ${reason.trim()}` : '.'}`,
              tag: `sug-${word}`,
            },
      );
    }
    return { ok: true, updated: pending.length };
  }

  private async notifyAdmins(word: string, username: string) {
    const admins = await this.prisma.user.findMany({ where: { role: 'ADMIN', deletedAt: null }, select: { id: true } });
    for (const a of admins) {
      void this.push.send(a.id, {
        title: 'Novi predlog reči',
        body: `${username} predlaže „${toLatin(word).toUpperCase()}“.`,
        tag: 'suggestions',
      });
    }
  }

  private view(r: Prisma.WordSuggestionGetPayload<object>) {
    return {
      id: r.id,
      word: r.word,
      latin: toLatin(r.word),
      length: r.length,
      note: r.note,
      status: r.status,
      reason: r.reason,
      createdAt: r.createdAt,
      decidedAt: r.decidedAt,
    };
  }
}
