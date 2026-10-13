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

/** ISO nedelja (ponedeljak–nedelja) u vremenskoj zoni igre, npr. "2026-W42". */
export function weekKey(date = new Date()) {
  const { y, m, d } = parts(date);
  const local = new Date(Date.UTC(Number(y), Number(m) - 1, Number(d)));
  const dow = local.getUTCDay() || 7; // 1 = ponedeljak … 7 = nedelja
  local.setUTCDate(local.getUTCDate() + 4 - dow); // četvrtak iste ISO nedelje
  const isoYear = local.getUTCFullYear();
  const week = Math.ceil(((local.getTime() - Date.UTC(isoYear, 0, 1)) / 86_400_000 + 1) / 7);
  return `${isoYear}-W${String(week).padStart(2, '0')}`;
}
export function previousWeekKey(date = new Date()) {
  return weekKey(new Date(date.getTime() - 7 * 86_400_000));
}
