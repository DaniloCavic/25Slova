import { useEffect, useState } from 'react';
import { api, getToken, setToken } from './api';
import { Dashboard } from './pages/Dashboard';
import { Words } from './pages/Words';
import { Users } from './pages/Users';
import { Settings } from './pages/Settings';

type Page = 'dashboard' | 'words' | 'users' | 'settings';
const PAGES: { id: Page; label: string }[] = [
  { id: 'dashboard', label: 'Pregled' },
  { id: 'words', label: 'Rečnik' },
  { id: 'users', label: 'Korisnici' },
  { id: 'settings', label: 'Podešavanja' },
];

export function App() {
  const [authed, setAuthed] = useState(!!getToken());
  const [page, setPage] = useState<Page>(() => (location.hash.slice(1) as Page) || 'dashboard');

  useEffect(() => {
    const out = () => setAuthed(false);
    window.addEventListener('slova-logout', out);
    return () => window.removeEventListener('slova-logout', out);
  }, []);

  useEffect(() => {
    location.hash = page;
  }, [page]);

  if (!authed) return <Login onDone={() => setAuthed(true)} />;

  return (
    <div className="layout">
      <nav className="sidebar">
        <h1>
          25 <span>Slova</span> admin
        </h1>
        {PAGES.map((p) => (
          <a key={p.id} className={page === p.id ? 'active' : ''} onClick={() => setPage(p.id)}>
            {p.label}
          </a>
        ))}
        <a
          className="logout"
          onClick={() => {
            setToken(null);
            setAuthed(false);
          }}
        >
          Odjava
        </a>
      </nav>
      <main>
        {page === 'dashboard' && <Dashboard />}
        {page === 'words' && <Words />}
        {page === 'users' && <Users />}
        {page === 'settings' && <Settings />}
      </main>
    </div>
  );
}

function Login({ onDone }: { onDone: () => void }) {
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      const res = await api('POST', '/auth/login', { login, password });
      if (res.user.role !== 'ADMIN') throw new Error('Ovaj nalog nema administratorska prava.');
      setToken(res.accessToken);
      onDone();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="card login" onSubmit={submit}>
      <h2>25 Slova — administracija</h2>
      <input placeholder="Korisničko ime ili e-mail" value={login} onChange={(e) => setLogin(e.target.value)} autoFocus />
      <input placeholder="Lozinka" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
      {error && <div className="error">{error}</div>}
      <button disabled={busy || !login || !password}>Prijava</button>
    </form>
  );
}
