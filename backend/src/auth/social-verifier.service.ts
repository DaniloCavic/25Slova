import { Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { createRemoteJWKSet, jwtVerify } from 'jose';

export type SocialProvider = 'google' | 'apple';

export interface SocialIdentity {
  provider: SocialProvider;
  subject: string;
  email: string | null;
  emailVerified: boolean;
  name: string | null;
}

const GOOGLE_JWKS = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
const APPLE_JWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

function audiences(envName: string): string[] {
  return (process.env[envName] || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

/** Proverava ID token koji je aplikacija dobila od Google-a ili Apple-a. */
@Injectable()
export class SocialVerifierService {
  async verify(provider: SocialProvider, idToken: string): Promise<SocialIdentity> {
    const aud = audiences(provider === 'google' ? 'GOOGLE_CLIENT_IDS' : 'APPLE_CLIENT_IDS');
    if (!aud.length) {
      throw new ServiceUnavailableException(`Prijava preko ${provider} još nije podešena na serveru.`);
    }
    try {
      const { payload } =
        provider === 'google'
          ? await jwtVerify(idToken, GOOGLE_JWKS, {
              issuer: ['https://accounts.google.com', 'accounts.google.com'],
              audience: aud,
            })
          : await jwtVerify(idToken, APPLE_JWKS, { issuer: 'https://appleid.apple.com', audience: aud });
      const ev = payload.email_verified;
      return {
        provider,
        subject: String(payload.sub),
        email: typeof payload.email === 'string' ? payload.email.toLowerCase() : null,
        emailVerified: ev === true || ev === 'true',
        name: typeof payload.name === 'string' ? payload.name : null,
      };
    } catch {
      throw new UnauthorizedException('Prijava nije uspela. Pokušajte ponovo.');
    }
  }
}
