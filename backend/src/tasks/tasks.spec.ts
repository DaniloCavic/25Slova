import { challengeHits } from './tasks.service';

const board = (rows: string[]) => rows.join('').split('').map((c) => (c === '.' ? null : c));

describe('glavni dnevni zadatak', () => {
  it('nalazi reči u redovima, kolonama i dijagonalama, u oba smera', () => {
    const b = board(['КУЋАШ', 'ГОРТС', 'Р....', 'О....', 'Г....']);
    // КУЋА u 1. redu, СТРОГ unazad u 2. redu, РОГ odozgo nadole u 1. koloni (Г-Р-О-Г: ГРОГ → РОГ)
    expect(challengeHits(b, ['КУЋА', 'СТРОГ', 'РОГ', 'ЊИВА'])).toEqual([true, true, true, false]);
  });
  it('prazna polja prekidaju reč', () => {
    const b = board(['КУ.А.', '.....', '.....', '.....', '.....']);
    expect(challengeHits(b, ['КУЋА'])).toEqual([false]);
  });
});
