# Kako da pokrenete 25 Slova na svom računaru — korak po korak (Windows)

Prvi put sve traje oko sat vremena (instalacije). Posle se igra pokreće za 2 minuta (vidi deo F na kraju).

> Sve komande se kucaju u **Command Prompt** (cmd), ne u PowerShell-u:
> pritisnite taster **Windows**, otkucajte `cmd` i pritisnite **Enter**. Otvoriće se crni prozor.
> Komandu otkucate (ili nalepite desnim klikom) i pritisnete **Enter**.

---

## A. Instalacija programa (samo prvi put)

### A1. Git (za preuzimanje projekta)
1. Otvorite https://git-scm.com/download/win
2. Kliknite na **"Click here to download"**, pokrenite preuzeti fajl.
3. Na svim ekranima samo klikćite **Next**, pa **Install**, pa **Finish**.

### A2. Node.js (pokreće server)
1. Otvorite https://nodejs.org
2. Preuzmite verziju označenu sa **LTS** (Windows Installer, `.msi`).
3. Pokrenite je i klikćite **Next** → prihvatite uslove → **Next** … → **Install** → **Finish**.

### A3. PostgreSQL (baza podataka)
1. Otvorite https://www.postgresql.org/download/windows/ i kliknite **"Download the installer"**.
2. Preuzmite verziju **16.x** za **Windows x86-64** i pokrenite je.
3. Klikćite **Next**. Kada traži **Password** — upišite lozinku i **zapišite je na papir**.
   Koristite samo slova i brojeve (npr. `Baza2026`), bez znakova `@ # / : %`.
4. Port ostavite **5432**, klikćite **Next** do kraja → **Install**.
5. Na poslednjem ekranu **isključite** kvačicu „Stack Builder“ i kliknite **Finish**.

### A4. Google Chrome
Ako ga nemate: https://www.google.com/chrome

### A5. Flutter (pokreće aplikaciju)
1. Otvorite https://docs.flutter.dev/get-started/install/windows/web
2. Preuzmite **zip** fajl sa Flutter SDK-om (dugme sa nazivom tipa `flutter_windows_3.x.x-stable.zip`).
3. Na disku **C:** napravite folder `src` (dakle `C:\src`).
4. Desni klik na zip → **Extract All…** → upišite `C:\src` → **Extract**.
   Treba da postoji folder `C:\src\flutter\bin`.
5. Dodajte Flutter u PATH:
   - Pritisnite **Windows**, otkucajte `env`, izaberite **"Edit environment variables for your account"**
     (srpski: „Uredite promenljive okruženja za svoj nalog“).
   - U gornjoj listi kliknite na **Path** → **Edit…** → **New** → upišite `C:\src\flutter\bin` → **OK** → **OK**.
6. **Zatvorite sve cmd prozore** i otvorite novi. Otkucajte:
   ```
   flutter --version
   ```
   Ako ispiše verziju — uspelo je. (Prvi put može da traje minut-dva.)

---

## B. Preuzimanje projekta (samo prvi put)

U cmd prozoru otkucajte, red po red (Enter posle svakog):
```
cd %USERPROFILE%\Documents
git clone https://github.com/DaniloCavic/25Slova.git
cd 25Slova
git checkout claude/mobile-game-serbian-a6err7
```
Ako se otvori prozor za prijavu na GitHub — prijavite se svojim nalogom.
Projekat je sada u folderu **Dokumenti\25Slova**.

---

## C. Baza i server (samo prvi put)

### C1. Napravite bazu
1. Pritisnite **Windows**, otkucajte `pgAdmin 4` i otvorite ga.
2. Levo kliknite na **Servers** → **PostgreSQL 16** → upišite lozinku iz koraka A3.
3. Desni klik na **Databases** → **Create** → **Database…**
4. U polje **Database** upišite `slova` → **Save**. Zatvorite pgAdmin.

### C2. Podesite server
U cmd prozoru:
```
cd %USERPROFILE%\Documents\25Slova\backend
copy .env.example .env
notepad .env
```
Otvoriće se Notepad. Izmenite tri reda (ostalo ne dirajte):

- `DATABASE_URL` — umesto **drugog** `postgres` upišite svoju lozinku iz A3, npr.:
  ```
  DATABASE_URL="postgresql://postgres:Baza2026@localhost:5432/slova?schema=public"
  ```
- `JWT_SECRET` — upišite bilo koji dugačak niz slova, npr. `JWT_SECRET="nekiDugackiTajniNiz12345abc"`
- `ADMIN_PASSWORD` — lozinka za admin panel, npr. `ADMIN_PASSWORD="Admin2026"`
  (korisničko ime je `admin25`, iz reda `ADMIN_USERNAME`)

Sačuvajte (**Ctrl + S**) i zatvorite Notepad.

### C3. Instalirajte i pripremite server
U istom cmd prozoru, red po red (svaki može da traje minut-dva):
```
npm install
npx prisma migrate deploy
npm run seed
npm run build
```
Posle `npm run seed` treba da piše: **„Uvezeno 858 novih reči“**.

### C4. Pripremite admin panel
```
cd ..\admin
npm install
npm run build
```

---

## D. Pokretanje servera

```
cd %USERPROFILE%\Documents\25Slova\backend
npm start
```
Sačekajte poruku: **„25 Slova server radi na portu 3000“**.

⚠️ **Ovaj prozor ostavite otvoren** — dok je otvoren, server radi. Zatvaranje = gašenje servera.

**Admin panel:** u Chrome-u otvorite http://localhost:3000/admin
i prijavite se sa `admin25` i lozinkom iz `ADMIN_PASSWORD`.

---

## E. Pokretanje aplikacije

Otvorite **novi** cmd prozor (server ostaje u prvom) i otkucajte:
```
cd %USERPROFILE%\Documents\25Slova\mobile
flutter pub get
flutter run -d chrome
```
Prvi put traje nekoliko minuta. Zatim se otvara Chrome sa aplikacijom.

1. Kliknite **Napravi nalog**, popunite podatke, **Registruj se**. Dobićete 30 tokena.
2. **Za partiju je potreban drugi igrač.** U istom Chrome prozoru pritisnite **Ctrl + Shift + N**
   (otvara se Incognito prozor). Iskopirajte adresu iz prvog prozora
   (izgleda kao `http://localhost:54321`) i nalepite je u Incognito prozor.
   Napravite **drugi nalog** (drugo korisničko ime i e-mail).
3. U oba prozora kliknite **„Igraj — nasumični protivnik“** — partija počinje.
   Ili: u jednom **„Igraj sa prijateljem (kod)“ → Kreiraj**, a u drugom **„Unesi kod prijatelja“**.
4. U partiji: kliknite slovo dole, pa prazno polje na tabli, pa **Potvrdi potez**.
   Kada protivnik izabere slovo, vi ga samo postavite na svoje polje.

Aplikaciju zaustavljate tako što u njenom cmd prozoru pritisnete **q** (ili zatvorite prozor).

---

## F. Sledeći put (kada je sve već instalirano)

**Prozor 1 (server):**
```
cd %USERPROFILE%\Documents\25Slova\backend
npm start
```
**Prozor 2 (aplikacija):**
```
cd %USERPROFILE%\Documents\25Slova\mobile
flutter run -d chrome
```
Ako sam u međuvremenu poslao izmene, pre toga u bilo kom prozoru:
```
cd %USERPROFILE%\Documents\25Slova
git pull
```
pa ponovite C3 i C4 (bez kreiranja baze).

---

## Česti problemi

| Poruka | Rešenje |
|---|---|
| `'flutter' is not recognized` | PATH nije podešen (A5 korak 5) ili niste otvorili **novi** cmd prozor posle toga. |
| `'npm' is not recognized` | Node.js nije instaliran (A2). Zatvorite i ponovo otvorite cmd. |
| `password authentication failed` | Pogrešna lozinka baze u `.env` (C2). Otvorite ponovo sa `notepad .env`. |
| `Database 'slova' does not exist` | Niste napravili bazu (C1). |
| `EADDRINUSE ... 3000` | Server već radi u drugom prozoru — zatvorite taj prozor. |
| Aplikacija kaže „Nema veze sa serverom“ | Prozor sa serverom (D) nije otvoren ili je server ugašen. |
| `running scripts is disabled` | Koristite **cmd**, ne PowerShell. |

`flutter doctor` može da prijavi da nedostaju Android Studio ili Visual Studio — to za probu u Chrome-u **nije potrebno**, zanemarite.

Ako negde zapne — pošaljite mi sliku ekrana ili tekst greške.

---

## Mac (ukratko)
Umesto cmd koristite aplikaciju **Terminal**. Razlike: Node.js i PostgreSQL (Postgres.app) se instaliraju sa istih sajtova,
Flutter po uputstvu za macOS, umesto `%USERPROFILE%\Documents` pišite `~/Documents`,
umesto `copy` pišite `cp`, a umesto `notepad .env` pišite `open -e .env`. Putanje se pišu sa `/` umesto `\`.
