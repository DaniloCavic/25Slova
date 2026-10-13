import { User } from '@prisma/client';
import { levelForCents, levelProgress, toPoints } from '../game/engine/rules';

/** Podaci koje vlasnik naloga vidi o sebi. */
export function selfView(u: User, extra: { weeklyPoints: number; monthlyPoints: number; yearlyPoints: number }) {
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
    totalPoints: toPoints(u.totalPoints),
    weeklyPoints: extra.weeklyPoints,
    monthlyPoints: extra.monthlyPoints,
    yearlyPoints: extra.yearlyPoints,
    level: levelForCents(u.totalPoints),
    levelProgress: levelProgress(toPoints(u.totalPoints)),
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
    level: levelForCents(u.totalPoints),
  };
}
