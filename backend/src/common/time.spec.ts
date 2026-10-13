import { previousWeekKey, weekKey } from './time';

describe('nedelje (ISO, po vremenu u Srbiji)', () => {
  it('računa ISO nedelju', () => {
    expect(weekKey(new Date('2026-10-13T12:00:00Z'))).toBe('2026-W42');
    expect(weekKey(new Date('2026-12-31T12:00:00Z'))).toBe('2026-W53');
    expect(weekKey(new Date('2027-01-03T12:00:00Z'))).toBe('2026-W53');
    expect(weekKey(new Date('2027-01-04T12:00:00Z'))).toBe('2027-W01');
  });
  it('nedelja počinje u ponoć po beogradskom vremenu', () => {
    // nedelja 23:30 UTC = ponedeljak 01:30 u Beogradu (letnje vreme)
    expect(weekKey(new Date('2026-10-11T21:30:00Z'))).toBe('2026-W41');
    expect(weekKey(new Date('2026-10-11T22:30:00Z'))).toBe('2026-W42');
  });
  it('prethodna nedelja', () => {
    expect(previousWeekKey(new Date('2027-01-04T12:00:00Z'))).toBe('2026-W53');
  });
});
