import { useCallback, useEffect, useState } from 'react';
import { api, fmtDate } from '../api';

export function Words() {
  const [search, setSearch] = useState('');
  const [length, setLength] = useState('');
  const [page, setPage] = useState(1);
  const [data, setData] = useState<any>(null);
  const [newWord, setNewWord] = useState('');
  const [msg, setMsg] = useState<{ ok?: string; err?: string }>({});
  const [bulkOpen, setBulkOpen] = useState(false);
  const [bulkText, setBulkText] = useState('');
  const [bulkResult, setBulkResult] = useState<any>(null);
  const [editing, setEditing] = useState<{ id: string; value: string } | null>(null);
  const [check, setCheck] = useState('');
  const [checkResult, setCheckResult] = useState<any>(null);

  const load = useCallback(() => {
    const q = new URLSearchParams({ page: String(page), pageSize: '50' });
    if (search) q.set('search', search);
    if (length) q.set('length', length);
    api('GET', `/admin/words?${q}`).then(setData).catch((e) => setMsg({ err: e.message }));
  }, [search, length, page]);

  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);

  async function add(e: React.FormEvent) {
    e.preventDefault();
    try {
      const w = await api('POST', '/admin/words', { word: newWord });
      setMsg({ ok: `Dodata reč ${w.word} (${w.latin}).` });
      setNewWord('');
      load();
    } catch (err) {
      setMsg({ err: (err as Error).message });
    }
  }

  async function remove(w: any) {
    if (!confirm(`Obrisati reč ${w.word} (${w.latin})?`)) return;
    try {
      await api('DELETE', `/admin/words/${w.id}`);
      setMsg({ ok: `Obrisana reč ${w.word}.` });
      load();
    } catch (err) {
      setMsg({ err: (err as Error).message });
    }
  }

  async function saveEdit() {
    if (!editing) return;
    try {
      await api('PATCH', `/admin/words/${editing.id}`, { word: editing.value });
      setEditing(null);
      load();
    } catch (err) {
      setMsg({ err: (err as Error).message });
    }
  }

  async function bulk() {
    try {
      const r = await api('POST', '/admin/words/bulk', { text: bulkText });
      setBulkResult(r);
      load();
    } catch (err) {
      setMsg({ err: (err as Error).message });
    }
  }

  async function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (f) setBulkText(await f.text());
  }

  async function doCheck(e: React.FormEvent) {
    e.preventDefault();
    setCheckResult(await api('GET', `/admin/words/check?word=${encodeURIComponent(check)}`));
  }

  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;

  return (
    <>
      <h2>Rečnik</h2>
      <div className="card">
        <p className="muted" style={{ marginTop: 0 }}>
          Reči se unose latinicom ili ćirilicom i čuvaju ćirilicom. Lj, Nj i Dž su po jedno slovo. Za igru važe reči od 2
          do 5 slova, u nominativu jednine ili množine, bez ličnih imena, skraćenica i brendova. Ako latinično „nj“, „lj“
          ili „dž“ nisu jedno slovo (npr. „injekcija“), reč unesite ćirilicom.
        </p>
        <form className="row" onSubmit={add}>
          <input className="grow" placeholder="Nova reč (npr. kuća ili КУЋА)" value={newWord} onChange={(e) => setNewWord(e.target.value)} />
          <button disabled={!newWord.trim()}>Dodaj reč</button>
          <button type="button" className="secondary" onClick={() => setBulkOpen(!bulkOpen)}>
            Masovni uvoz
          </button>
        </form>
        {msg.ok && <div className="success">{msg.ok}</div>}
        {msg.err && <div className="error">{msg.err}</div>}
        {bulkOpen && (
          <div style={{ marginTop: 12 }}>
            <p className="muted">Jedna reč po redu (ili razdvojene zarezom). Možete učitati .txt fajl.</p>
            <input type="file" accept=".txt,.csv" onChange={onFile} />
            <textarea value={bulkText} onChange={(e) => setBulkText(e.target.value)} placeholder={'kuća\nreka\nnjiva'} />
            <div className="row">
              <button onClick={bulk} disabled={!bulkText.trim()}>
                Uvezi
              </button>
              {bulkResult && (
                <span>
                  Dodato: <b>{bulkResult.added}</b>, već postoji: <b>{bulkResult.duplicates}</b>, neispravno:{' '}
                  <b>{bulkResult.invalid.length}</b>
                </span>
              )}
            </div>
            {bulkResult?.invalid?.length > 0 && (
              <ul className="error">
                {bulkResult.invalid.slice(0, 50).map((i: any) => (
                  <li key={i.input}>
                    {i.input}: {i.error}
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}
      </div>

      <div className="card">
        <form className="row" onSubmit={doCheck}>
          <input className="grow" placeholder="Proveri da li je reč u rečniku" value={check} onChange={(e) => setCheck(e.target.value)} />
          <button className="secondary">Proveri</button>
          {checkResult &&
            (checkResult.error ? (
              <span className="error">{checkResult.error}</span>
            ) : (
              <span>
                <span className="word">{checkResult.word}</span> ({checkResult.latin}):{' '}
                {checkResult.inDictionary ? <span className="badge green">u rečniku</span> : <span className="badge red">nije u rečniku</span>}
              </span>
            ))}
        </form>
      </div>

      <div className="card">
        <div className="row" style={{ marginBottom: 12 }}>
          <input className="grow" placeholder="Pretraga" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} />
          <select value={length} onChange={(e) => { setLength(e.target.value); setPage(1); }}>
            <option value="">Sve dužine</option>
            {[2, 3, 4, 5].map((n) => (
              <option key={n} value={n}>
                {n} slova
              </option>
            ))}
          </select>
          <span className="muted">{data?.total ?? 0} reči</span>
        </div>
        <table className="responsive">
          <thead>
            <tr>
              <th>Reč</th>
              <th>Latinica</th>
              <th>Slova</th>
              <th>Dodao</th>
              <th>Datum</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {data?.items.map((w: any) => (
              <tr key={w.id}>
                <td data-label="Reč" className="word">
                  {editing?.id === w.id ? (
                    <input value={editing?.value ?? ""} onChange={(e) => setEditing({ id: w.id, value: e.target.value })} autoFocus />
                  ) : (
                    w.word
                  )}
                </td>
                <td data-label="Latinica">{w.latin}</td>
                <td data-label="Slova">{w.length}</td>
                <td data-label="Dodao" className="muted hide-sm">{w.addedBy ?? 'početni rečnik'}</td>
                <td data-label="Datum" className="muted hide-sm">{fmtDate(w.createdAt)}</td>
                <td data-label="">
                  <div className="row">
                    {editing?.id === w.id ? (
                      <>
                        <button className="ok" onClick={saveEdit}>Sačuvaj</button>
                        <button className="secondary" onClick={() => setEditing(null)}>Otkaži</button>
                      </>
                    ) : (
                      <>
                        <button className="secondary" onClick={() => setEditing({ id: w.id, value: w.latin })}>Izmeni</button>
                        <button className="danger" onClick={() => remove(w)}>Obriši</button>
                      </>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <div className="pager">
          <button className="secondary" disabled={page <= 1} onClick={() => setPage(page - 1)}>←</button>
          <span>
            {page} / {pages}
          </span>
          <button className="secondary" disabled={page >= pages} onClick={() => setPage(page + 1)}>→</button>
        </div>
      </div>
    </>
  );
}
