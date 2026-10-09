import { Injectable, Logger } from '@nestjs/common';
import { createPublicKey, createVerify, KeyObject } from 'crypto';

/**
 * Provera AdMob "Server-Side Verification" povratnog poziva.
 * Google potpisuje query string ECDSA ključem; javni ključevi se preuzimaju sa
 * https://www.gstatic.com/admob/reward/verifier-keys.json
 * Nagrada se dodeljuje samo ako je potpis ispravan (specifikacija, 5.3).
 */
@Injectable()
export class AdVerifierService {
  private readonly log = new Logger(AdVerifierService.name);
  private keys = new Map<string, KeyObject>();
  private fetchedAt = 0;

  private async loadKeys() {
    if (Date.now() - this.fetchedAt < 6 * 3600_000 && this.keys.size) return;
    const res = await fetch('https://www.gstatic.com/admob/reward/verifier-keys.json');
    const body = (await res.json()) as { keys: { keyId: number; pem: string }[] };
    this.keys = new Map(body.keys.map((k) => [String(k.keyId), createPublicKey(k.pem)]));
    this.fetchedAt = Date.now();
  }

  /** rawQuery = deo URL-a posle "?", tačno onako kako ga je AdMob poslao. */
  async verify(rawQuery: string): Promise<boolean> {
    const sigIdx = rawQuery.indexOf('&signature=');
    if (sigIdx < 0) return false;
    const message = rawQuery.slice(0, sigIdx);
    const params = new URLSearchParams(rawQuery.slice(sigIdx + 1));
    const signature = params.get('signature');
    const keyId = params.get('key_id');
    if (!signature || !keyId) return false;
    try {
      await this.loadKeys();
      const key = this.keys.get(keyId);
      if (!key) return false;
      const v = createVerify('sha256');
      v.update(message);
      return v.verify(key, Buffer.from(signature, 'base64url'));
    } catch (e) {
      this.log.error(`Provera reklame nije uspela: ${e}`);
      return false;
    }
  }
}
