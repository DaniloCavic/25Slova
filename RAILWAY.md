# Postavljanje servera na Railway — korak po korak

Railway pokreće server i bazu na internetu. Kada pošaljem izmene na GitHub, Railway sam ažurira server.

**Cena:** Hobby plan je 5 $ mesečno i u to je uključeno 5 $ potrošnje. Za ovu igru u probnoj fazi
to bi trebalo da bude dovoljno ili blizu toga. Novi nalozi dobijaju i probni kredit.
Tačne cene: https://railway.com/pricing

---

## 1. Nalog
1. Otvorite https://railway.com i kliknite **Login** → **Login with GitHub** → dozvolite pristup.
2. Ako traži plan, izaberite **Hobby** i unesite karticu.

## 2. Novi projekat iz GitHub-a
1. Kliknite **New Project** (ili **+ New**) → **Deploy from GitHub repo**.
2. Ako ne vidite repozitorijum: **Configure GitHub App** → dozvolite pristup repozitorijumu **25Slova**.
3. Izaberite **DaniloCavic/25Slova**.
4. Railway odmah počinje da gradi — **prvi pokušaj će pasti** jer još nema bazu. To je očekivano.

## 3. Grana
1. Kliknite na kockicu servisa (**25Slova**) → **Settings**.
2. U delu **Source** → **Branch** proverite da piše `claude/mobile-game-serbian-a6err7`. Ako ne piše, izaberite je.

## 4. Baza podataka
1. U projektu kliknite **+ New** (ili **Create**) → **Database** → **Add PostgreSQL**.
2. Pojaviće se nova kockica **Postgres**. Ne treba ništa da podešavate.

## 5. Podešavanja servera (Variables)
1. Kliknite na kockicu **25Slova** → kartica **Variables** → **+ New Variable** (ili **Raw Editor**).
2. Dodajte ovih šest promenljivih (Raw Editor: nalepite sve odjednom, pa izmenite lozinke):
   ```
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   JWT_SECRET=ovde-upisite-dugacak-nasumican-niz-slova-i-brojeva-123
   ADMIN_USERNAME=admin25
   ADMIN_PASSWORD=ovde-upisite-jaku-admin-lozinku
   GAME_TIMEZONE=Europe/Belgrade
   PORT=3000
   ```
   - `DATABASE_URL` upišite tačno ovako, sa `${{ }}` — Railway sam ubaci adresu baze.
   - `JWT_SECRET` — bilo šta dugačko (40+ znakova), niko ne treba da ga zna.
   - `ADMIN_PASSWORD` — lozinka za admin panel na internetu. **Neka bude jaka i zapišite je.**
3. Kliknite **Deploy** (ili **Apply changes**).

## 6. Disk za profilne slike
1. Na kockici **25Slova** desni klik (ili **Settings**) → **Attach Volume** / **+ Volume**.
2. **Mount path:** `/app/backend/uploads` → **Create**.

## 7. Javna adresa
1. Kockica **25Slova** → **Settings** → **Networking** → **Generate Domain**.
2. Ako pita za port (**Target port**), upišite **3000**.
3. Dobićete adresu tipa `https://25slova-production.up.railway.app`.

## 8. Provera
1. Sačekajte da u **Deployments** piše **Success / Active** (prvi put 3–6 minuta).
2. Otvorite `https://VAŠA-ADRESA/api/health` — treba da piše `{"ok":true,...}`.
3. Otvorite `https://VAŠA-ADRESA/admin` i prijavite se sa `admin25` i lozinkom iz koraka 5.

Pri prvom pokretanju server sam pravi tabele, uvozi početni rečnik i pravi admin nalog.

**Pošaljite mi tu adresu** — sa njom pravim Android aplikaciju (APK) za telefon.

## Ako nešto ne radi
Kockica **25Slova** → **Deployments** → kliknite poslednji → **View logs**. Pošaljite mi sliku ekrana poslednjih redova.
