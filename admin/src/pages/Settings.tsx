import { useEffect, useState } from 'react';
import { api } from '../api';

const FIELDS: { key: string; label: string; help: string }[] = [
  { key: 'initialLevelRange', label: 'Početni raspon levela', help: '1 = igrač Level 5 se prvo uparuje sa Level 4–6' },
  { key: 'expandEverySeconds', label: 'Proširenje na svakih (sekundi)', help: 'Koliko čekanja proširuje raspon za 1 level' },
  { key: 'maxLevelRange', label: 'Najveći raspon levela', help: '9 = na kraju može bilo ko sa bilo kim' },
  { key: 'privateCodeMinutes', label: 'Trajanje koda privatne partije (min)', help: 'Posle toga kod ističe' },
];

export function Settings() {
  const [s, setS] = useState<Record<string, number> | null>(null);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    api('GET', '/admin/settings/matchmaking').then(setS);
  }, []);

  async function save() {
    try {
      setS(await api('PUT', '/admin/settings/matchmaking', s));
      setMsg('Sačuvano.');
    } catch (e) {
      setMsg((e as Error).message);
    }
  }

  if (!s) return <div className="muted">Učitavanje…</div>;
  return (
    <>
      <h2>Podešavanja uparivanja</h2>
      <div className="card">
        <div className="form-grid">
          {FIELDS.map((f) => (
            <label key={f.key}>
              {f.label}
              <input type="number" min={0} value={s[f.key]} onChange={(e) => setS({ ...s, [f.key]: Number(e.target.value) })} />
              <span>{f.help}</span>
            </label>
          ))}
        </div>
        <div className="row" style={{ marginTop: 12 }}>
          <button onClick={save}>Sačuvaj</button>
          {msg && <span className="success">{msg}</span>}
        </div>
      </div>
    </>
  );
}
