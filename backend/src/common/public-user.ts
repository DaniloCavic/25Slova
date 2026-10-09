import { User } from '@prisma/client';
import { levelForPoints } from '../game/engine/rules';

/** Podaci koje vlasnik naloga vidi o sebi. */
export function selfView(u: User, extra: { monthlyPoints: number; yearlyPoints: number }) {
  return {
    id: u.id,
    username: u.username,
    fullName: u.fullName,
    gender: u.gender,
    birthDate: u.birthDate ? u.birthDate.toISOString().slice(0, 10) : null,
    email: u.email,
    phone: u.phone,
    avatarUrl: u.avatarUrl,
    role: u.role,
    tokens: u.tokens,
    totalPoints: u.totalPoints,
    monthlyPoints: extra.monthlyPoints,
    yearlyPoints: extra.yearlyPoints,
    level: levelForPoints(u.totalPoints),
    hasPassword: !!u.passwordHash,
    linkedGoogle: !!u.googleId,
    linkedApple: !!u.appleId,
    createdAt: u.createdAt,
  };
}

/** Ono što drugi igrači vide — bez e-maila i telefona (specifikacija, 3). */
export function publicView(u: Pick<User, 'id' | 'username' | 'avatarUrl' | 'totalPoints'>) {
  return {
    id: u.id,
    username: u.username,
    avatarUrl: u.avatarUrl,
    level: levelForPoints(u.totalPoints),
  };
}
