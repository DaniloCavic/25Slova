/**
 * Kalendarski dan/mesec/godina računaju se u vremenskoj zoni igre
 * (podrazumevano Europe/Belgrade), a ne po satu na telefonu.
 */
export const GAME_TZ = process.env.GAME_TIMEZONE || 'Europe/Belgrade';

function parts(date: Date) {
  const f = new Intl.DateTimeFormat('en-CA', {
    timeZone: GAME_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const p = Object.fromEntries(f.formatToParts(date).map((x) => [x.type, x.value]));
  return { y: p.year, m: p.month, d: p.day };
}

export function dayKey(date = new Date()) {
  const { y, m, d } = parts(date);
  return `${y}-${m}-${d}`;
}
export function monthKey(date = new Date()) {
  const { y, m } = parts(date);
  return `${y}-${m}`;
}
export function yearKey(date = new Date()) {
  return parts(date).y;
}
export function previousMonthKey(date = new Date()) {
  const { y, m } = parts(date);
  const mi = Number(m) - 1;
  return mi === 0 ? `${Number(y) - 1}-12` : `${y}-${String(mi).padStart(2, '0')}`;
}
export function previousYearKey(date = new Date()) {
  return String(Number(parts(date).y) - 1);
}
