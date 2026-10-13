import { useCallback, useEffect, useState } from 'react';
import { api, fmtDate } from '../api';

const GENDER: Record<string, string> = { MALE: 'Muški', FEMALE: 'Ženski' };

function StatusBadge({ u }: { u: any }) {
  if (u.deletedAt) return <span className="badge">obrisan</span>;
  if (u.isBlocked) return <span className="badge red">blokiran</span>;
  return <span className="badge green">aktivan</span>;
}

export function Users() {
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('active');
  const [page, setPage] = useState(1);
  const [data, setData] = useState<any>(null);
  const [selected, setSelected] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  const load = useCallback(() => {
    const q = new URLSearchParams({ page: String(page), status });
    if (search) q.set('search', search);
    api('GET', `/admin/users?${q}`).then(setData);
  }, [search, status, page]);

  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);

  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;

  return (
    <>
      <h2>Korisnici</h2>
      <div className="card">
        <div className="row" style={{ marginBottom: 12 }}>
          <input className="grow" placeholder="Pretraga: korisničko ime, ime, e-mail, telefon" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} />
          <select value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>
            <option value="active">Aktivni i blokirani</option>
            <option value="blocked">Samo blokirani</option>
            <option value="deleted">Obrisani</option>
            <option value="all">Svi</option>
          </select>
          <button onClick={() => setCreating(true)}>+ Novi korisnik</button>
        </div>
        <table>
          <thead>
            <tr>
              <th>Korisničko ime</th>
              <th>Ime i prezime</th>
              <th>E-mail</th>
              <th>Level</th>
              <th>Poeni</th>
              <th>Tokeni</th>
              <th>Status</th>
              <th>Registrovan</th>
            </tr>
          </thead>
          <tbody>
            {data?.items.map((u: any) => (
              <tr key={u.id} className="clickable" onClick={() => setSelected(u.id)}>
                <td>
                  <b>{u.username}</b> {u.role === 'ADMIN' && <span className="badge blue">admin</span>}
                </td>
                <td>{u.fullName}</td>
                <td>{u.email ?? '—'}</td>
                <td>{u.level}</td>
                <td>{u.totalPoints}</td>
                <td>{u.tokens}</td>
                <td><StatusBadge u={u} /></td>
                <td className="muted">{fmtDate(u.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <div className="pager">
          <span className="muted">{data?.total ?? 0} korisnika</span>
          <button className="secondary" disabled={page <= 1} onClick={() => setPage(page - 1)}>←</button>
          <span>{page} / {pages}</span>
          <button className="secondary" disabled={page >= pages} onClick={() => setPage(page + 1)}>→</button>
        </div>
      </div>
      {selected && <UserDrawer id={selected} onClose={() => { setSelected(null); load(); }} />}
      {creating && <CreateUser onClose={() => { setCreating(false); load(); }} />}
    </>
  );
}

function ProfileForm({ initial, onSubmit, withPassword, submitLabel, withTokens = false }: {
  initial: any;
  withTokens?: boolean;
  onSubmit: (v: any) => Promise<void>;
  withPassword: 'required' | 'optional';
  submitLabel: string;
}) {
  const [v, setV] = useState<any>({ ...initial, password: '' });
  const [err, setErr] = useState('');
  const [ok, setOk] = useState('');
  const set = (k: string) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setV({ ...v, [k]: e.target.value });

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setErr('');
    setOk('');
    const body: any = {
      username: v.username,
      fullName: v.fullName,
      gender: v.gender || undefined,
      birthDate: v.birthDate || undefined,
      email: v.email || undefined,
      phone: v.phone ?? '',
      role: v.role,
    };
    if (v.password) body.password = v.password;
    if (withTokens) body.tokens = Number(v.tokens) || 0;
    try {
      await onSubmit(body);
      setOk('Sačuvano.');
    } catch (e2) {
      setErr((e2 as Error).message);
    }
  }

  return (
    <form onSubmit={submit}>
      <div className="form-grid">
        <label>Korisničko ime<input value={v.username ?? ''} onChange={set('username')} /></label>
        <label>Ime i prezime<input value={v.fullName ?? ''} onChange={set('fullName')} /></label>
        <label>Pol
          <select value={v.gender ?? ''} onChange={set('gender')}>
            <option value="">—</option>
            <option value="MALE">Muški</option>
            <option value="FEMALE">Ženski</option>
          </select>
        </label>
        <label>Datum rođenja<input type="date" value={v.birthDate ?? ''} onChange={set('birthDate')} /></label>
        <label>E-mail<input value={v.email ?? ''} onChange={set('email')} /></label>
        <label>Telefon<input value={v.phone ?? ''} onChange={set('phone')} /></label>
        <label>Uloga
          <select value={v.role ?? 'USER'} onChange={set('role')}>
            <option value="USER">Igrač</option>
            <option value="ADMIN">Administrator</option>
          </select>
        </label>
        <label>{withPassword === 'required' ? 'Lozinka' : 'Nova lozinka (opciono)'}
          <input type="password" value={v.password} onChange={set('password')} />
        </label>
        {withTokens && <label>Početni tokeni<input type="number" value={v.tokens} onChange={set('tokens')} /></label>}
      </div>
      {err && <div className="error">{err}</div>}
      {ok && <div className="success">{ok}</div>}
      <div className="row" style={{ marginTop: 12 }}>
        <button>{submitLabel}</button>
      </div>
    </form>
  );
}

function CreateUser({ onClose }: { onClose: () => void }) {
  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="drawer" onClick={(e) => e.stopPropagation()}>
        <div className="row"><h2 className="grow">Novi korisnik</h2><button className="secondary" onClick={onClose}>Zatvori</button></div>
        <div className="card">
          <ProfileForm
            initial={{ role: 'USER', gender: 'MALE', tokens: 0 }}
            withPassword="required"
            withTokens
            submitLabel="Kreiraj"
            onSubmit={async (body) => {
              await api('POST', '/admin/users', body);
              onClose();
            }}
          />
        </div>
      </div>
    </div>
  );
}

function UserDrawer({ id, onClose }: { id: string; onClose: () => void }) {
  const [d, setD] = useState<any>(null);
  const [reason, setReason] = useState('');
  const [tokens, setTokens] = useState('');
  const [points, setPoints] = useState('');
  const [note, setNote] = useState('');
  const [msg, setMsg] = useState<{ ok?: string; err?: string }>({});

  const load = useCallback(() => api('GET', `/admin/users/${id}`).then(setD), [id]);
  useEffect(() => {
    load();
  }, [load]);

  async function act(fn: () => Promise<unknown>, ok: string) {
    setMsg({});
    try {
      await fn();
      setMsg({ ok });
      await load();
    } catch (e) {
      setMsg({ err: (e as Error).message });
    }
  }

  if (!d) return null;
  const u = d.user;
  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="drawer" onClick={(e) => e.stopPropagation()}>
        <div className="row">
          {u.avatarUrl && <img src={u.avatarUrl} alt="" width={48} height={48} style={{ borderRadius: 24, objectFit: 'cover' }} />}
          <h2 className="grow" style={{ margin: 0 }}>{u.username} <StatusBadge u={u} /></h2>
          <button className="secondary" onClick={onClose}>Zatvori</button>
        </div>
        <p className="muted">
          Level {u.level} · ukupno {u.totalPoints} p · ova nedelja {u.weeklyPoints} p · ovaj mesec {u.monthlyPoints} p · ova godina {u.yearlyPoints} p · {u.tokens} tokena
          <br />
          Pol: {GENDER[u.gender] ?? '—'} · Google: {u.linkedGoogle ? 'da' : 'ne'} · Apple: {u.linkedApple ? 'da' : 'ne'} · poslednji put: {fmtDate(u.lastSeenAt)}
          {u.isBlocked && <><br /><span className="error">Blokiran {fmtDate(u.blockedAt)}{u.blockedReason ? ` — ${u.blockedReason}` : ''}</span></>}
        </p>
        {msg.ok && <div className="success">{msg.ok}</div>}
        {msg.err && <div className="error">{msg.err}</div>}

        {!u.deletedAt && (
          <>
            <div className="card">
              <h3 style={{ marginTop: 0 }}>Podaci</h3>
              <ProfileForm
                key={JSON.stringify(u)}
                initial={u}
                withPassword="optional"
                submitLabel="Sačuvaj izmene"
                onSubmit={async (body) => {
                  await api('PATCH', `/admin/users/${id}`, body);
                  await load();
                }}
              />
            </div>

            <div className="card">
              <h3 style={{ marginTop: 0 }}>Blokada</h3>
              {u.isBlocked ? (
                <button className="ok" onClick={() => act(() => api('POST', `/admin/users/${id}/unblock`), 'Korisnik je odblokiran.')}>Odblokiraj</button>
              ) : (
                <div className="row">
                  <input className="grow" placeholder="Razlog (vidi ga korisnik)" value={reason} onChange={(e) => setReason(e.target.value)} />
                  <button className="danger" onClick={() => act(() => api('POST', `/admin/users/${id}/block`, { reason }), 'Korisnik je blokiran.')}>Blokiraj</button>
                </div>
              )}
            </div>

            <div className="card">
              <h3 style={{ marginTop: 0 }}>Tokeni i poeni</h3>
              <div className="row">
                <input type="number" placeholder="± tokena" value={tokens} onChange={(e) => setTokens(e.target.value)} style={{ width: 120 }} />
                <input className="grow" placeholder="Napomena" value={note} onChange={(e) => setNote(e.target.value)} />
                <button disabled={!Number(tokens)} onClick={() => act(() => api('POST', `/admin/users/${id}/tokens`, { amount: Number(tokens), note }), 'Tokeni izmenjeni.')}>Primeni tokene</button>
              </div>
              <div className="row" style={{ marginTop: 8 }}>
                <input type="number" placeholder="± poena" value={points} onChange={(e) => setPoints(e.target.value)} style={{ width: 120 }} />
                <button disabled={!Number(points)} onClick={() => act(() => api('POST', `/admin/users/${id}/points`, { amount: Number(points) }), 'Poeni izmenjeni.')}>Primeni poene</button>
                <span className="muted">Menja ukupni, mesečni i godišnji saldo.</span>
              </div>
            </div>
          </>
        )}

        <div className="card">
          <h3 style={{ marginTop: 0 }}>Poslednje partije</h3>
          <table>
            <thead><tr><th>Ishod</th><th>Tip</th><th>Poeni table</th><th>Reči</th><th>Saldo</th><th>Kraj</th></tr></thead>
            <tbody>
              {d.matches.map((m: any) => (
                <tr key={m.matchId}>
                  <td>{m.outcome === 'WIN' ? <span className="badge green">pobeda</span> : m.outcome === 'LOSS' ? <span className="badge red">poraz</span> : m.outcome === 'DRAW' ? <span className="badge">nerešeno</span> : m.status}</td>
                  <td>{m.mode === 'PRIVATE' ? 'kod' : 'nasumično'}</td>
                  <td>{m.score}</td>
                  <td>{m.wordsCount}</td>
                  <td>{m.pointsDelta > 0 ? `+${m.pointsDelta}` : m.pointsDelta}</td>
                  <td className="muted">{fmtDate(m.endedAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="card">
          <h3 style={{ marginTop: 0 }}>Istorija tokena</h3>
          <table>
            <thead><tr><th>Vrsta</th><th>Iznos</th><th>Stanje posle</th><th>Napomena</th><th>Vreme</th></tr></thead>
            <tbody>
              {d.tokenHistory.map((t: any) => (
                <tr key={t.id}><td>{t.type}</td><td>{t.amount > 0 ? `+${t.amount}` : t.amount}</td><td>{t.balanceAfter}</td><td>{t.note ?? ''}</td><td className="muted">{fmtDate(t.createdAt)}</td></tr>
              ))}
            </tbody>
          </table>
        </div>

        {!u.deletedAt && u.role !== 'ADMIN' && (
          <div className="card">
            <h3 style={{ marginTop: 0 }}>Brisanje naloga</h3>
            <p className="muted">Lični podaci se trajno brišu; odigrane partije ostaju anonimne.</p>
            <button
              className="danger"
              onClick={() => {
                if (confirm(`Trajno obrisati nalog ${u.username}?`)) {
                  act(() => api('DELETE', `/admin/users/${id}`), 'Nalog je obrisan.');
                }
              }}
            >
              Obriši nalog
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
