/**
 * Javne stranice koje traži Google Play: politika privatnosti (/privatnost)
 * i brisanje naloga preko weba (/brisanje-naloga).
 */
const email = () => process.env.SUPPORT_EMAIL || 'podrska@25slova.rs';

const layout = (title: string, body: string) => `<!doctype html>
<html lang="sr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — 25 Slova</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; background: #0b1a3c; color: #e9eefb; line-height: 1.55; }
  main { max-width: 760px; margin: 0 auto; padding: 28px 18px 60px; }
  h1 { color: #ffc93c; font-size: 28px; margin: 0 0 4px; }
  h2 { color: #ffc93c; font-size: 19px; margin: 28px 0 6px; }
  a { color: #8db7ff; }
  .muted { color: #a9b6d6; font-size: 14px; }
  .card { background: #13295c; border: 1px solid #2c4a8f; border-radius: 16px; padding: 18px; margin-top: 18px; }
  label { display: block; margin: 12px 0 4px; font-weight: 600; }
  input { width: 100%; box-sizing: border-box; padding: 12px; border-radius: 10px; border: 1px solid #2c4a8f; background: #0b1a3c; color: #fff; font-size: 16px; }
  button { margin-top: 18px; width: 100%; padding: 14px; border: 0; border-radius: 12px; background: #e5484d; color: #fff; font-size: 17px; font-weight: 700; cursor: pointer; }
  button:disabled { opacity: .5; }
  #msg { margin-top: 14px; font-weight: 600; }
  li { margin: 4px 0; }
</style>
</head>
<body><main>${body}</main></body>
</html>`;

export function privacyPage() {
  return layout(
    'Politika privatnosti',
    `
<h1>Politika privatnosti</h1>
<p class="muted">Igra „25 Slova“ · poslednja izmena: 5. novembar 2026.</p>

<p>Ova politika objašnjava koje podatke igra „25 Slova“ (aplikacija za Android, iPhone i web verzija) prikuplja, zašto i kako ih možete obrisati.</p>

<h2>Koje podatke prikupljamo</h2>
<ul>
  <li><b>Podaci naloga:</b> korisničko ime, ime i prezime, e-mail adresa, pol, datum rođenja, lozinka (čuva se samo u šifrovanom obliku) i, ako je postavite, profilna slika.</li>
  <li><b>Podaci o igri:</b> odigrane partije (table, reči, rezultat), bodovi, level, medalje, tokeni, zadaci, lista prijatelja i predlozi reči za rečnik.</li>
  <li><b>Obaveštenja:</b> ako su obaveštenja uključena, čuvamo oznaku uređaja (Firebase Cloud Messaging ili Web Push) da bismo poslali poruke kao što su „Na potezu si“, izazov prijatelja ili podsetnik za dnevnu nagradu.</li>
  <li><b>Tehnički podaci:</b> vreme poslednje prijave i podaci potrebni za rad servera (npr. IP adresa u privremenim zapisima o radu servera).</li>
</ul>

<h2>Zašto ih koristimo</h2>
<ul>
  <li>da biste mogli da igrate sa drugim igračima, pratite rezultate i rang liste;</li>
  <li>da drugi igrači vide vaše korisničko ime, profilnu sliku, level, medalje i rezultate (e-mail, telefon, ime i prezime i datum rođenja se <b>ne prikazuju</b> drugim igračima);</li>
  <li>za obaveštenja koja ste uključili, promenu lozinke i zaštitu od zloupotrebe.</li>
</ul>
<p>Podatke <b>ne prodajemo</b> i ne delimo sa trećim licima radi reklama. Za slanje obaveštenja koristimo Google Firebase, a server i baza podataka se nalaze kod pružaoca usluga Railway.</p>

<h2>Koliko dugo čuvamo podatke</h2>
<p>Podatke čuvamo dok imate nalog. Kada obrišete nalog, lični podaci (ime, e-mail, pol, datum rođenja, lozinka, slika, oznake uređaja) se odmah brišu; ranije odigrane partije ostaju samo pod oznakom „obrisan nalog“, bez ličnih podataka, da bi rezultati drugih igrača ostali ispravni.</p>

<h2>Brisanje naloga</h2>
<p>Nalog možete obrisati u igri: <b>Moj profil → Obriši nalog</b>, ili na stranici <a href="/brisanje-naloga">Brisanje naloga</a>.</p>

<h2>Deca</h2>
<p>Igra nije namenjena deci mlađoj od 13 godina.</p>

<h2>Kontakt</h2>
<p>Za sva pitanja o privatnosti pišite na <a href="mailto:${email()}">${email()}</a>.</p>
`,
  );
}

export function deleteAccountPage() {
  return layout(
    'Brisanje naloga',
    `
<h1>Brisanje naloga</h1>
<p class="muted">Igra „25 Slova“</p>
<p>Nalog možete obrisati i u samoj igri: <b>Moj profil → Obriši nalog</b>. Ovde to možete uraditi preko pregledača — prijavite se korisničkim imenom (ili e-mailom) i lozinkom.</p>
<p><b>Šta se briše:</b> korisničko ime, ime i prezime, e-mail, pol, datum rođenja, lozinka, profilna slika, tokeni, lista prijatelja i oznake uređaja za obaveštenja. Odigrane partije ostaju samo pod oznakom „obrisan nalog“, bez ličnih podataka. Brisanje je trajno i ne može se poništiti.</p>

<div class="card">
  <form id="f">
    <label for="login">Korisničko ime ili e-mail</label>
    <input id="login" autocomplete="username" required>
    <label for="password">Lozinka</label>
    <input id="password" type="password" autocomplete="current-password" required>
    <button id="btn" type="submit">Trajno obriši nalog</button>
    <div id="msg"></div>
  </form>
</div>
<p class="muted">Ako ste nalog napravili bez lozinke ili ste je zaboravili, pišite na <a href="mailto:${email()}">${email()}</a> sa e-mail adrese naloga.</p>

<script>
  document.getElementById('f').addEventListener('submit', async function (e) {
    e.preventDefault();
    var msg = document.getElementById('msg'), btn = document.getElementById('btn');
    if (!confirm('Da li sigurno želite da trajno obrišete nalog?')) return;
    btn.disabled = true; msg.style.color = '#e9eefb'; msg.textContent = 'Brisanje…';
    try {
      var r = await fetch('/api/auth/login', { method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ login: document.getElementById('login').value.trim(), password: document.getElementById('password').value }) });
      var j = await r.json();
      if (!r.ok) throw new Error(j.message || 'Prijava nije uspela.');
      var d = await fetch('/api/me', { method: 'DELETE', headers: { authorization: 'Bearer ' + j.accessToken } });
      if (!d.ok) throw new Error('Brisanje nije uspelo. Pokušajte ponovo.');
      msg.style.color = '#3ddc84'; msg.textContent = 'Nalog je obrisan.';
      document.getElementById('f').reset();
    } catch (err) {
      msg.style.color = '#ff8a8a'; msg.textContent = err.message;
      btn.disabled = false;
    }
  });
</script>
`,
  );
}

/** Otisci ključeva kojima je potpisana Android aplikacija (ključ za otpremanje + Google Play ključ). */
const UPLOAD_KEY_SHA256 = '31:BB:9F:75:5F:3D:9A:32:7C:0C:1A:B5:1D:ED:3C:DC:92:80:E7:CE:B0:46:BF:36:96:63:B2:68:51:BA:9D:34';

/** /.well-known/assetlinks.json — Android otvara linkove igre direktno u aplikaciji. */
export function assetLinks() {
  const extra = (process.env.ANDROID_CERT_SHA256 || '')
    .split(',')
    .map((s) => s.trim().toUpperCase())
    .filter(Boolean);
  return [
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: 'rs.slova25.slova25',
        sha256_cert_fingerprints: [...new Set([UPLOAD_KEY_SHA256, ...extra])],
      },
    },
  ];
}
