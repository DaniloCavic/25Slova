/**
 * End-to-end provera servera: dva igrača, privatna i nasumična partija, admin funkcije.
 * Pokretanje (server mora da radi):  npx ts-node scripts/smoke.ts [http://localhost:3000]
 */
import { io, Socket } from 'socket.io-client';

const BASE = process.argv[2] || 'http://localhost:3000';
const API = `${BASE}/api`;
let failures = 0;

function check(cond: unknown, msg: string) {
  console.log(`${cond ? '✔' : '✘'} ${msg}`);
  if (!cond) failures++;
}

async function http(method: string, path: string, body?: unknown, token?: string) {
  const res = await fetch(API + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: (await res.json().catch(() => null)) as any };
}

function connect(token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const s = io(BASE, { auth: { token }, transports: ['websocket'] });
    s.once('session', () => resolve(s));
    s.once('auth:error', (e) => reject(new Error(e.error)));
  });
}

const emit = (s: Socket, ev: string, data?: unknown) =>
  new Promise<any>((resolve) => s.emit(ev, data ?? {}, resolve));

/** Automatski igra: kad je na potezu, postavi slovo na prvo slobodno polje. */
function autoplay(s: Socket, letters: string[]) {
  let i = 0;
  const onState = (st: any) => {
    if (!st.isMyTurn) return;
    const cell = st.me.board.findIndex((c: string | null) => c === null);
    const letter = st.phase === 'CHOOSE' ? letters[i++ % letters.length] : null;
    s.emit('match:move', { cell, letter }, (r: any) => {
      if (!r.ok) console.log('  potez odbijen:', r.error);
    });
  };
  s.on('match:start', onState);
  s.on('match:state', onState);
  return new Promise<any>((resolve) =>
    s.once('match:end', (r) => {
      s.off('match:start', onState);
      s.off('match:state', onState);
      resolve(r);
    }),
  );
}

async function main() {
  const tag = Date.now().toString(36).slice(-5);
  const mk = (n: string) => ({
    username: `${n}_${tag}`,
    fullName: `Test ${n}`,
    gender: 'MALE',
    birthDate: '1995-05-17',
    email: `${n}_${tag}@test.rs`,
    phone: '+381 64 123 4567',
    password: 'lozinka123',
    passwordConfirm: 'lozinka123',
  });

  // --- registracija i validacija
  const bad1 = await http('POST', '/auth/register', { ...mk('x'), username: 'abcd' });
  check(bad1.status === 400 && /najmanje 5/.test(bad1.body.message), `kratko korisničko ime odbijeno: ${bad1.body.message}`);
  const bad2 = await http('POST', '/auth/register', { ...mk('y'), passwordConfirm: 'drugacija1' });
  check(bad2.status === 400 && /ne poklapaju/.test(bad2.body.message), 'lozinke se moraju poklapati');

  const a = await http('POST', '/auth/register', mk('marko'));
  const b = await http('POST', '/auth/register', mk('jelena'));
  check(a.status === 201 && a.body.dailyReward.granted && a.body.user.tokens === 30, 'registracija + dnevna nagrada 30 tokena');
  check(b.status === 201, 'drugi igrač registrovan');
  const dup = await http('POST', '/auth/register', mk('marko'));
  check(dup.status === 409, 'zauzeto korisničko ime odbijeno');

  const login = await http('POST', '/auth/login', { login: mk('marko').username, password: 'lozinka123' });
  check(login.status === 201 && login.body.dailyReward.granted === false, 'druga prijava istog dana ne daje nagradu');
  const wrong = await http('POST', '/auth/login', { login: mk('marko').username, password: 'pogresna1' });
  check(wrong.status === 401, 'pogrešna lozinka odbijena');

  const tA = a.body.accessToken as string;
  const tB = b.body.accessToken as string;

  // --- privatna partija preko koda
  const sA = await connect(tA);
  const sB = await connect(tB);
  const created = await emit(sA, 'private:create');
  check(created.ok && /^[A-Z0-9]{6}$/.test(created.code), `privatna partija kreirana, kod ${created.code}`);
  const self = await emit(sA, 'private:join', { code: created.code });
  check(!self.ok, 'domaćin ne može da uđe u svoju partiju');

  const endA = autoplay(sA, ['К', 'У', 'Ћ', 'А', 'С']);
  const endB = autoplay(sB, ['Р', 'О', 'Г', 'Т']);
  const startB = new Promise<any>((r) => sB.once('match:start', r));
  const joined = await emit(sB, 'private:join', { code: created.code });
  check(joined.ok, 'drugi igrač ušao preko koda');
  const st = await startB;
  check([1, 3, 5].includes(st.initialLetters) && st.me.board.filter(Boolean).length === st.initialLetters,
    `partija počela: tip ${st.type}, ${st.initialLetters} početnih slova, ${st.turnSeconds}s po potezu`);
  check(st.opponent.board === undefined, 'protivnikova tabla nije vidljiva tokom partije');

  const [rA, rB] = await Promise.all([endA, endB]);
  check(rA.endReason === 'BOARDS_FULL', 'partija završena popunjavanjem tabli');
  check(rA.me.board.every(Boolean) && rB.me.board.every(Boolean), 'obe table pune');
  const linesOk = rA.me.lines.length === 12 && rA.me.lines.every((l: any) => l.points <= 5);
  check(linesOk, `12 nizova, najviše 5 po nizu (A: ${rA.me.points} p / ${rA.me.wordsCount} reči, B: ${rB.me.points} p / ${rB.me.wordsCount} reči)`);
  check(
    (rA.outcome === 'DRAW' && rB.outcome === 'DRAW') || (rA.outcome !== rB.outcome),
    `ishod: A=${rA.outcome} (${rA.pointsDelta}), B=${rB.outcome} (${rB.pointsDelta})`,
  );
  // Isto slovo u svakom zajedničkom potezu: obe table imaju isti multiskup slova.
  const sorted = (bd: string[]) => [...bd].sort().join('');
  check(sorted(rA.me.board) === sorted(rB.me.board), 'oba igrača su dobila ista slova');

  const meA = await http('GET', '/me', undefined, tA);
  check(meA.body.user.tokens === 20, `posle partije A ima 20 tokena (ima ${meA.body.user.tokens})`);

  // --- nasumično uparivanje + predaja
  const endA2 = new Promise<any>((r) => sA.once('match:end', r));
  const startA2 = new Promise<any>((r) => sA.once('match:start', r));
  check((await emit(sA, 'queue:join')).ok, 'A u redu za nasumičnu partiju');
  check((await emit(sB, 'queue:join')).ok, 'B u redu za nasumičnu partiju');
  const st2 = await startA2;
  check(st2.mode === 'RANDOM', 'nasumični protivnik pronađen');
  check((await emit(sA, 'match:resume')).match?.matchId === st2.matchId, 'ponovno povezivanje vraća partiju');
  await emit(sB, 'match:resign');
  const r2 = await endA2;
  check(r2.outcome === 'WIN' && r2.endReason === 'RESIGNED', 'predaja = pobeda protivnika');

  const meB = await http('GET', '/me', undefined, tB);
  check(meB.body.user.tokens === 10, `B ima 10 tokena posle dve partije (ima ${meB.body.user.tokens})`);
  const third = await emit(sB, 'queue:join');
  check(third.ok, 'B može još jednu partiju sa 10 tokena');
  await emit(sB, 'queue:leave');

  // --- rang-liste i najbolja tabla
  const lb = await http('GET', '/leaderboard?period=month', undefined, tA);
  check(lb.status === 200 && Array.isArray(lb.body.items), `mesečna rang-lista (${lb.body.items.length} igrača)`);
  const best = await http('GET', '/best-board', undefined, tA);
  check(best.status === 200 && best.body.overall?.board?.length === 25, 'najbolja tabla ikad');

  // --- admin
  const nonAdmin = await http('GET', '/admin/users', undefined, tA);
  check(nonAdmin.status === 403, 'običan korisnik nema pristup adminu');
  const adm = await http('POST', '/auth/login', { login: 'admin25', password: 'Admin12345' });
  check(adm.status === 201 && adm.body.user.role === 'ADMIN', 'admin prijava');
  const tAdm = adm.body.accessToken;
  const word = await http('POST', '/admin/words', { word: 'grožđ' }, tAdm);
  check((word.status === 201 && word.body.word === 'ГРОЖЂ') || word.status === 409, `admin dodaje reč (${word.body.word ?? word.body.message})`);
  const tooLong = await http('POST', '/admin/words', { word: 'lubenica' }, tAdm);
  check(tooLong.status === 400, `predugačka reč odbijena: ${tooLong.body.message}`);
  const bulk = await http('POST', '/admin/words/bulk', { text: 'džak\nnjiva\nkonj1\nabc' }, tAdm);
  check(bulk.status === 201 && bulk.body.invalid.length === 1, `masovni uvoz: ${JSON.stringify(bulk.body)}`);
  const chk = await http('GET', '/admin/words/check?word=njiva', undefined, tAdm);
  check(chk.body.inDictionary === true && chk.body.word === 'ЊИВА', 'provera reči: NJIVA = ЊИВА (4 slova)');
  if (word.status === 201) {
    const del = await http('DELETE', `/admin/words/${word.body.id}`, undefined, tAdm);
    check(del.status === 200, 'admin briše reč');
  }
  const users = await http('GET', `/admin/users?search=${tag}`, undefined, tAdm);
  check(users.body.total === 2, 'admin pretraga korisnika');
  const idB = b.body.user.id;
  const edit = await http('PATCH', `/admin/users/${idB}`, { fullName: 'Jelena Izmenjena', phone: '+381601112233' }, tAdm);
  check(edit.body.fullName === 'Jelena Izmenjena', 'admin menja podatke korisnika');
  const adj = await http('POST', `/admin/users/${idB}/tokens`, { amount: 50, note: 'test' }, tAdm);
  check(adj.body.tokens === 60, 'admin dodaje tokene');
  const kicked = new Promise<any>((r) => sB.once('account:blocked', r));
  const blk = await http('POST', `/admin/users/${idB}/block`, { reason: 'Test blokade' }, tAdm);
  check(blk.body.isBlocked, 'admin blokira korisnika');
  await kicked;
  check(true, 'blokiran korisnik izbačen sa socket veze');
  const blockedLogin = await http('POST', '/auth/login', { login: mk('jelena').username, password: 'lozinka123' });
  check(blockedLogin.status === 403 && /blokiran/.test(blockedLogin.body.message), `blokiran ne može da se prijavi: ${blockedLogin.body.message}`);
  const oldToken = await http('GET', '/me', undefined, tB);
  check(oldToken.status === 403, 'stari token blokiranog korisnika više ne važi');
  await http('POST', `/admin/users/${idB}/unblock`, {}, tAdm);
  const created2 = await http('POST', '/admin/users', { ...mk('novi'), tokens: 100 }, tAdm);
  check(created2.status === 201 && created2.body.tokens === 100, 'admin kreira korisnika');
  const delU = await http('DELETE', `/admin/users/${created2.body.id}`, undefined, tAdm);
  check(delU.status === 200, 'admin briše korisnika');
  const stats = await http('GET', '/admin/stats', undefined, tAdm);
  check(stats.status === 200 && stats.body.matchesTotal >= 2, `admin statistika: ${JSON.stringify(stats.body.live)}`);

  sA.close();
  sB.close();
  console.log(failures ? `\n${failures} PROVERA NIJE PROŠLO` : '\nSve provere su prošle.');
  process.exit(failures ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
