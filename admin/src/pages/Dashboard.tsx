import { useEffect, useState } from 'react';
import { api } from '../api';

const TX_LABELS: Record<string, string> = {
  DAILY_REWARD: 'Dnevne nagrade',
  MATCH_ENTRY: 'Ulazi u partije',
  MATCH_REFUND: 'Povraćaji',
  AD_REWARD: 'Reklame',
  PURCHASE: 'Kupovine',
  ADMIN_ADJUST: 'Admin izmene',
  SIGNUP_BONUS: 'Bonus za registraciju',
};

export function Dashboard() {
  const [s, setS] = useState<any>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    const load = () => api('GET', '/admin/stats').then(setS).catch((e) => setError(e.message));
    load();
    const t = setInterval(load, 10_000);
    return () => clearInterval(t);
  }, []);

  if (error) return <div className="error">{error}</div>;
  if (!s) return <div className="muted">Učitavanje…</div>;
  const items: [string, number][] = [
    ['Korisnika', s.users],
    ['Novih danas', s.newToday],
    ['Aktivnih danas', s.activeToday],
    ['Blokiranih', s.blocked],
    ['Partija danas', s.matchesToday],
    ['Partija ukupno', s.matchesTotal],
    ['Reči u rečniku', s.words],
    ['Partija u toku', s.live.activeMatches],
    ['Čeka protivnika', s.live.inQueue],
    ['Privatnih kodova', s.live.privateWaiting],
  ];
  return (
    <>
      <h2>Pregled</h2>
      <div className="stats">
        {items.map(([label, v]) => (
          <div className="stat" key={label}>
            <span className="muted">{label}</span>
            <b>{v}</b>
          </div>
        ))}
      </div>
      <div className="card" style={{ marginTop: 16 }}>
        <h3 style={{ marginTop: 0 }}>Tokeni ovog meseca</h3>
        <table className="responsive">
          <thead>
            <tr>
              <th>Vrsta</th>
              <th>Broj transakcija</th>
              <th>Ukupno tokena</th>
            </tr>
          </thead>
          <tbody>
            {s.tokensThisMonth.map((t: any) => (
              <tr key={t.type}>
                <td data-label="Vrsta">{TX_LABELS[t.type] ?? t.type}</td>
                <td data-label="Broj transakcija">{t.count}</td>
                <td data-label="Ukupno tokena">{t.amount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
