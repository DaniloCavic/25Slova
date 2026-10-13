# 25 Slova

Onlajn igra rečima za dva igrača, za Android i iOS, prilagođena srpskom jeziku.
Svaki igrač ima tablu 5 × 5, igrači naizmenično biraju slovo koje obojica postavljaju na svoje table,
a na kraju se broje reči u redovima, kolonama i dijagonalama.

## Sadržaj repozitorijuma

| Folder | Šta je | Tehnologija |
|---|---|---|
| `backend/` | Server: nalozi, tokeni, rečnik, partije u realnom vremenu, rang-liste, admin API | NestJS (TypeScript), PostgreSQL (Prisma), Socket.IO |
| `admin/` | Admin panel u pregledaču (server ga servira na `/admin`) | React + Vite |
| `mobile/` | Mobilna aplikacija — jedan kod za Android i iPhone | Flutter |

Server je jedini sudija: on određuje čiji je potez, tajmer, živote, rezultat, tokene, poene, levele i medalje.
Telefon samo prikazuje stanje i šalje poteze, pa se igra ne može prevariti menjanjem sata ili aplikacije.

## Šta je urađeno (prva verzija)

**Igra**
- Tabla 5 × 5 po igraču; 1, 3 ili 5 početnih nasumičnih slova (ista polja i slova za oba igrača); tip partije je nasumičan.
- Srpska azbuka od 30 slova — Lj, Nj i Dž su jedno slovo i jedno polje. Slova se prikazuju latinicom; tamni i svetli režim prikaza.
- Naizmenični potezi: igrač bira slovo i polje, protivnik isto slovo postavlja na svoju tablu i bira sledeće.
- Serverski tajmer (30/45/60 s), 3 života, istek vremena = −1 život, gubitak sva 3 = poraz; vreme teče i bez veze.
- Ponovno povezivanje vraća igrača u partiju u toku. Predaja partije.
- Bodovanje: 12 nizova, oba smera čitanja, najduža reč (2–5 slova) po nizu, kraće reči unutar duže se ne sabiraju.
- Pobednik po poenima → broju reči → nerešeno. Nagrada `(poeni × reči) ÷ 7,2`, poraz −10, nerešeno 0.

**Nalozi i profil**
- Registracija (korisničko ime, ime i prezime, pol, datum rođenja, e-mail, telefon, lozinka + potvrda) i prijava.
- Zaboravljena lozinka (kod na e-mail), promena lozinke, profilna slika, izmena podataka, brisanje naloga.
- E-mail i telefon se ne prikazuju drugim igračima.
- Server je spreman za Google i Apple prijavu (provera tokena, dopuna profila, povezivanje bez preuzimanja tuđeg naloga).

**Tokeni, poeni, rang-liste**
- Svaka promena tokena je posebna transakcija. Dnevna nagrada 30 tokena (najviše jednom dnevno, zaštićeno i od istovremenih zahteva).
- Partija košta 10 tokena po igraču. Nagrada za reklamu (5 tokena) preko AdMob serverske provere potpisa.
- Ukupni, mesečni i godišnji saldo; leveli 1–10; mesečna i godišnja rang-lista sa pretragom igrača; istorija prethodnih perioda.
- Medalje za 1., 2. i 3. mesto na kraju meseca i godine (automatski, i nadoknadi ako je server bio ugašen).
- „Najbolja tabla ikad“ — ukupno i posebno za 1, 3 i 5 početnih slova, sa označenim početnim slovima.

**Uparivanje**
- Nasumični protivnik sličnog levela; raspon se postepeno širi dok igrač čeka (podesivo u admin panelu).
- Privatna partija preko koda od 6 znakova, sa rokom važenja; povezuje dva različita igrača.

**Admin panel** (`http://<server>/admin`)
- Rečnik: dodavanje, izmena i brisanje reči, masovni uvoz (lista ili .txt fajl), provera reči, pretraga, filter po dužini.
- Korisnici: pretraga, pregled (partije, tokeni, medalje), izmena podataka i uloge, nova lozinka, blokiranje uz razlog
  (korisnik se odmah izbacuje iz igre), odblokiranje, dodavanje/oduzimanje tokena i poena, kreiranje i brisanje naloga.
- Pregled: broj korisnika, aktivnih, partija, reči, partije u toku, red čekanja, tokeni po vrsti.
- Podešavanja uparivanja (rasponi levela, brzina širenja, trajanje koda).

## Pokretanje za razvoj

Potrebno: Node.js 22, PostgreSQL 16, Flutter 3.24+.

```bash
# 1) Server
cd backend
cp .env.example .env            # podesi DATABASE_URL, JWT_SECRET, ADMIN_USERNAME, ADMIN_PASSWORD
npm install
npx prisma migrate deploy       # pravi tabele
npm run seed                    # početni rečnik (~860 reči)
npm run build && npm start      # server na http://localhost:3000

# 2) Admin panel
cd ../admin
npm install
npm run build                   # server ga onda servira na http://localhost:3000/admin
# ili za razvoj sa automatskim osvežavanjem: npm run dev  →  http://localhost:5173/admin/

# 3) Mobilna aplikacija
cd ../mobile
flutter pub get
flutter run                                             # emulator (Android vidi server kao 10.0.2.2)
flutter run --dart-define=API_URL=http://192.168.1.10:3000   # pravi telefon u istoj Wi-Fi mreži
```

Prijava u admin panel: korisničko ime i lozinka iz `ADMIN_USERNAME` / `ADMIN_PASSWORD`
(nalog se automatski pravi pri prvom pokretanju servera). Admin može i drugim nalozima dati admin ulogu.

Server na produkciji: `docker compose up -d --build` (vidi `docker-compose.yml`; obavezno postaviti `JWT_SECRET` i `ADMIN_PASSWORD`).

## Testovi

```bash
cd backend && npm test                     # pravila igre: bodovanje, potezi, životi, izjednačenja, leveli
cd backend && npx ts-node scripts/smoke.ts # ceo tok preko pravog servera: registracija, 2 partije, admin (server mora da radi)
cd mobile && flutter test                  # azbuka, tabla, izbor slova
```

## Odluke o otvorenim pitanjima iz specifikacije

Gde specifikacija ostavlja izbor, primenjeno je sledeće (sve se lako menja):

1. **Naplata partije** (potvrđeno) — tokeni se oduzimaju tek kada je protivnik pronađen, oba igrača u istoj transakciji. Ako se server restartuje usred partije, partija se poništava i tokeni vraćaju.
2. **„Broj validnih reči“** (potvrđeno) — broj nizova (od 12) u kojima postoji validna reč. Tako je najveća nagrada tačno 60 × 12 ÷ 7,2 = 100.
3. **Zaokruživanje nagrade** — na najbliži ceo broj.
4. **Početna slova** (potvrđeno) — ista slova na istim poljima za oba igrača (fer start); slova se biraju po učestalosti u srpskom (retka Đ, Dž, F ređe ispadaju).
5. **Ko prvi bira slovo** — nasumično.
6. **Protivnikova tabla** (potvrđeno) — skrivena dok partija traje, otkriva se na kraju.
7. **Pobeda zbog gubitka života ili predaje** — pobednik dobija nagradu po formuli za svoju trenutnu tablu, gubitnik −10.
8. **Negativan saldo** — dozvoljen (specifikacija ne zabranjuje); takav igrač je Level 1.
9. **Najbolja tabla** — globalni rekord + posebni za 1, 3 i 5 početnih slova; računaju se samo partije završene popunjavanjem tabli; kod istog rezultata rekord zadržava onaj ko ga je prvi postigao; istorija ostaje u bazi.
10. **Medalje** — samo igrači sa više od 0 poena u periodu; kod istog broja poena ispred je onaj ko ih je ranije dostigao.
11. **Dan, mesec i godina** — računaju se po vremenu u Srbiji (`Europe/Belgrade`), ne po satu telefona.
12. **Registracija** — e-mail je obavezan (potreban za zaboravljenu lozinku), telefon nije; korisničko ime 5–20 znakova, bilo koji znakovi; lozinka najmanje 8 znakova sa slovom i brojem.
13. **Brisanje naloga** — lični podaci se trajno brišu, a odigrane partije ostaju anonimne (da protivnicima ne nestanu iz istorije).
14. **Rang-liste** — samo mesečna i godišnja (ukupna je izbačena na zahtev), sa pretragom igrača po imenu; pretraga pokazuje pravo mesto igrača na listi.
15. **Rečnik** — čuvaju se samo reči od 2 do 5 slova (duže ne mogu stati u niz). Unos latinicom se pretvara u ćirilicu; reči kod kojih „nj/lj/dž“ nisu jedno slovo (npr. „injekcija“) unose se ćirilicom.
16. **Google/Apple nalog sa istim e-mailom** kao postojeći nalog se ne spaja automatski (zaštita od preuzimanja naloga); korisnik se prijavi lozinkom i poveže nalog iz profila.
17. **Privatni kod** — 6 znakova, važi 10 minuta (podesivo); igrač koji je napravio kod mora biti u aplikaciji kada se drugi pridruži.

## Sledeći koraci

- **Rečnik** — početnih ~860 reči je samo za testiranje. Za pravu igru potrebna je velika odobrena baza (desetine hiljada imenica i prideva u nominativu); admin je uvozi kroz „Masovni uvoz“.
- **Google i Apple prijava u aplikaciji** — server je spreman; potrebni su Google Cloud / Apple Developer nalozi i client ID-jevi.
- **Nagrađene reklame** (AdMob) i **kupovina tokena** (Google Play / App Store uz serversku proveru kupovine) — potrebni su nalozi i odluka o paketima i cenama.
- Politika privatnosti, uslovi korišćenja, pravila kupovine; ikonica i izgled; analitika; push obaveštenja.
- Objava na Google Play i App Store (za iOS je potreban Mac i Apple Developer nalog, 99 USD godišnje).
- Za veliki broj istovremenih igrača: red čekanja i partije u toku preseliti u Redis da bi radilo više instanci servera.
