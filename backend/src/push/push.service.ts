import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';
import * as webpush from 'web-push';
import { PrismaService } from '../prisma/prisma.service';
import { dayKey, GAME_TZ } from '../common/time';
import { DAILY_REWARD } from '../game/engine/rules';

export interface PushMessage {
  title: string;
  body: string;
  /** Novo obaveštenje sa istim tagom zamenjuje staro (npr. „na potezu si“). */
  tag?: string;
  /** Putanja u igri koja se otvara dodirom (relativno na /igra/). */
  url?: string;
}

interface VapidKeys {
  publicKey: string;
  privateKey: string;
}

type FcmMessaging = { send(msg: unknown): Promise<string> };

/**
 * Obaveštenja na telefonu:
 * - Web Push (VAPID) — iPhone (aplikacija dodata na početni ekran) i pregledači; ključevi se
 *   prave sami pri prvom pokretanju i čuvaju u bazi.
 * - FCM (Firebase) — Android aplikacija; radi kada je postavljena promenljiva
 *   FIREBASE_SERVICE_ACCOUNT (JSON servisnog naloga iz Firebase konzole).
 */
@Injectable()
export class PushService implements OnApplicationBootstrap {
  private readonly log = new Logger(PushService.name);
  private vapid?: VapidKeys;
  private fcm?: FcmMessaging;

  constructor(private readonly prisma: PrismaService) {}

  async onApplicationBootstrap() {
    await this.initVapid().catch((e) => this.log.error(`Web Push nije pokrenut: ${e.message}`));
    await this.initFcm().catch((e) => this.log.error(`FCM nije pokrenut: ${e.message}`));
  }

  private async initVapid() {
    const row = await this.prisma.setting.findUnique({ where: { key: 'vapid' } });
    let keys = row?.value as VapidKeys | undefined;
    if (!keys?.publicKey || !keys?.privateKey) {
      keys = webpush.generateVAPIDKeys();
      await this.prisma.setting.upsert({
        where: { key: 'vapid' },
        create: { key: 'vapid', value: keys as unknown as Prisma.InputJsonValue },
        update: { value: keys as unknown as Prisma.InputJsonValue },
      });
      this.log.log('Napravljeni novi VAPID ključevi za Web Push.');
    }
    const subject = process.env.VAPID_SUBJECT || process.env.PUBLIC_URL || 'https://25slova-production.up.railway.app';
    webpush.setVapidDetails(subject, keys.publicKey, keys.privateKey);
    this.vapid = keys;
  }

  private async initFcm() {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!raw) return;
    const { initializeApp, cert } = await import('firebase-admin/app');
    const { getMessaging } = await import('firebase-admin/messaging');
    const app = initializeApp({ credential: cert(JSON.parse(raw)) }, 'push');
    this.fcm = getMessaging(app);
    this.log.log('FCM (Android obaveštenja) je uključen.');
  }

  config() {
    return { webPublicKey: this.vapid?.publicKey ?? null, fcm: !!this.fcm };
  }

  async subscribeWeb(userId: string, sub: { endpoint: string; keys: { p256dh: string; auth: string } }) {
    await this.prisma.pushSubscription.upsert({
      where: { endpoint: sub.endpoint },
      create: { userId, kind: 'WEB', endpoint: sub.endpoint, keys: sub.keys },
      update: { userId, keys: sub.keys },
    });
  }

  async subscribeFcm(userId: string, token: string) {
    await this.prisma.pushSubscription.upsert({
      where: { endpoint: token },
      create: { userId, kind: 'FCM', endpoint: token },
      update: { userId },
    });
  }

  async unsubscribe(userId: string, endpoint: string) {
    await this.prisma.pushSubscription.deleteMany({ where: { userId, endpoint } });
  }

  /** Šalje obaveštenje na sve uređaje igrača; neispravne pretplate briše. Greške ne prekidaju igru. */
  async send(userId: string, msg: PushMessage) {
    try {
      const subs = await this.prisma.pushSubscription.findMany({ where: { userId } });
      await Promise.all(subs.map((s) => this.sendOne(s, msg)));
    } catch (e) {
      this.log.warn(`Slanje obaveštenja nije uspelo: ${(e as Error).message}`);
    }
  }

  private async sendOne(s: { id: string; kind: string; endpoint: string; keys: Prisma.JsonValue }, msg: PushMessage) {
    try {
      if (s.kind === 'WEB') {
        if (!this.vapid) return;
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: s.keys as { p256dh: string; auth: string } },
          JSON.stringify(msg),
          { TTL: 60 * 60, urgency: 'high', topic: msg.tag?.slice(0, 32) },
        );
      } else {
        if (!this.fcm) return;
        await this.fcm.send({
          token: s.endpoint,
          notification: { title: msg.title, body: msg.body },
          data: { url: msg.url ?? '', tag: msg.tag ?? '' },
          android: { priority: 'high', notification: { tag: msg.tag } },
        });
      }
    } catch (e) {
      const err = e as { statusCode?: number; code?: string; message?: string };
      const gone =
        err.statusCode === 404 ||
        err.statusCode === 410 ||
        err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token';
      if (gone) await this.prisma.pushSubscription.delete({ where: { id: s.id } }).catch(() => undefined);
      else this.log.warn(`Obaveštenje nije poslato (${s.kind}): ${err.message}`);
    }
  }

  /** Svaki dan u 11:00 (vreme igre): podsetnik onima koji još nisu preuzeli dnevnu nagradu. */
  @Cron('0 11 * * *', { timeZone: GAME_TZ })
  async dailyReminder() {
    const today = dayKey();
    const users = await this.prisma.user.findMany({
      where: {
        isBlocked: false,
        deletedAt: null,
        pushSubscriptions: { some: {} },
        OR: [{ lastDailyRewardDay: null }, { lastDailyRewardDay: { not: today } }],
      },
      select: { id: true },
    });
    for (const u of users) {
      await this.send(u.id, {
        title: 'Dnevna nagrada te čeka! 🎁',
        body: `Uđi u 25 Slova i preuzmi svojih ${DAILY_REWARD} tokena.`,
        tag: 'daily',
      });
    }
    if (users.length) this.log.log(`Podsetnik za dnevnu nagradu poslat igračima: ${users.length}`);
  }
}
