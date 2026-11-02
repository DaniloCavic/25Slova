import { useCallback, useEffect, useState } from 'react';
import { api, fmtDate } from '../api';

type Status = 'PENDING' | 'ACCEPTED' | 'REJECTED';
const TABS: { id: Status; label: string }[] = [
  { id: 'PENDING', label: 'Na čekanju' },
  { id: 'ACCEPTED', label: 'Prihvaćeni' },
  { id: 'REJECTED', label: 'Odbijeni' },
];

/** Reči koje su igrači predložili za rečnik. Prihvatanje odmah dodaje reč u igru. */
export function Suggestions({ onChange }: { onChange?: () => void }) {
  const [status, setStatus] = useState<Status>('PENDING');
  const [items, setItems] = useState<any[] | null>(null);
  const [error, setError] = useState('');
  const [rejecting, setRejecting] = useState<{ id: string; reason: string } | null>(null);

  const load = useCallback(async () => {
    setError('');
    try {
      setItems(await api('GET', `/admin/suggestions?status=${status}`));
    } catch (e) {
      setError((e as Error).message);
    }
  }, [status]);

  useEffect(() => {
    setItems(null);
    void load();
  }, [load]);

  async function accept(s: any) {
    try {
      await api('POST', `/admin/suggestions/${s.id}/accept`);
      await load();
      onChange?.();
    } catch (e) {
      setError((e as Error).message);
    }
  }

  async function reject() {
    if (!rejecting) return;
    try {
      await api('POST', `/admin/suggestions/${rejecting.id}/reject`, { reason: rejecting.reason });
      setRejecting(null);
      await load();
      onChange?.();
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return (
    <>
      <h2>Predlozi reči</h2>
      <div className="card">
        <p className="muted" style={{ marginTop: 0 }}>
          Igrači predlažu reči koje nisu u rečniku. <b>Prihvati</b> odmah dodaje reč u igru, a igrači koji su je predložili
          dobijaju obaveštenje. Ista reč koju je predložilo više igrača prikazana je jednom.
        </p>
        <div className="row" style={{ marginBottom: 12 }}>
          {TABS.map((t) => (
            <button key={t.id} className={status === t.id ? '' : 'secondary'} onClick={() => setStatus(t.id)}>
              {t.label}
            </button>
          ))}
          <span className="muted">{items ? `${items.length} ${items.length % 10 === 1 && items.length % 100 !== 11 ? 'reč' : 'reči'}` : 'Učitavanje…'}</span>
        </div>
        {error && <div className="error">{error}</div>}
        {items && items.length === 0 && <p className="muted">Nema predloga.</p>}
        {items && items.length > 0 && (
          <table className="responsive">
            <thead>
              <tr>
                <th>Reč</th>
                <th>Slova</th>
                <th>Predložili</th>
                <th>Napomena</th>
                <th>Datum</th>
                {status === 'REJECTED' && <th>Razlog</th>}
                {status === 'PENDING' && <th></th>}
              </tr>
            </thead>
            <tbody>
              {items.map((s) => (
                <tr key={s.id}>
                  <td data-label="Reč">
                    <b>{s.latin}</b> <span className="muted word">{s.word}</span>
                  </td>
                  <td data-label="Slova">{s.length}</td>
                  <td data-label="Predložili">
                    {s.count > 1 && <span className="badge blue">{s.count} igrača</span>} {s.users.join(', ')}
                  </td>
                  <td data-label="Napomena" className="muted">{s.note || '—'}</td>
                  <td data-label="Datum" className="muted hide-sm">{fmtDate(s.decidedAt ?? s.createdAt)}</td>
                  {status === 'REJECTED' && <td data-label="Razlog" className="muted">{s.reason || '—'}</td>}
                  {status === 'PENDING' && (
                    <td data-label="">
                      {rejecting?.id === s.id ? (
                        <div className="row">
                          <input
                            placeholder="Razlog (nije obavezno)"
                            value={rejecting?.reason ?? ''}
                            onChange={(e) => setRejecting({ id: s.id, reason: e.target.value })}
                            autoFocus
                          />
                          <button className="danger" onClick={reject}>Odbij</button>
                          <button className="secondary" onClick={() => setRejecting(null)}>Otkaži</button>
                        </div>
                      ) : (
                        <div className="row">
                          <button className="ok" onClick={() => accept(s)}>Prihvati</button>
                          <button className="danger" onClick={() => setRejecting({ id: s.id, reason: '' })}>Odbij</button>
                        </div>
                      )}
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
