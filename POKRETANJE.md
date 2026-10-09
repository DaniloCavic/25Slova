# Kako da pokrenete i probate 25 Slova na svom računaru

Uputstvo je za Windows ili Mac. Jednom se instaliraju programi (oko sat vremena), a posle se sve pokreće za par minuta.

## 1. Instalirajte (jednom)

1. **Node.js 22** — https://nodejs.org (verzija „LTS“)
2. **PostgreSQL 16** — https://www.postgresql.org/download/ — pri instalaciji upišite lozinku za korisnika `postgres` i zapamtite je
3. **Flutter** — https://docs.flutter.dev/get-started/install (izaberite svoj sistem, pa „Web“ ili „Android“)
4. **Google Chrome**
5. **Git** — https://git-scm.com (Windows) — pa preuzmite projekat:
   ```
   git clone https://github.com/DaniloCavic/25Slova.git
   cd 25Slova
   git checkout claude/mobile-game-serbian-a6err7
   ```

## 2. Napravite bazu (jednom)

Otvorite „SQL Shell (psql)“ ili pgAdmin i izvršite:
```
CREATE DATABASE slova;
```

## 3. Pokrenite server (prvi terminal)

```
cd backend
copy .env.example .env        (na Mac-u: cp .env.example .env)
```
U fajlu `backend/.env` upišite svoju lozinku baze u `DATABASE_URL` (umesto drugog `postgres`), i izmislite `JWT_SECRET` i `ADMIN_PASSWORD`.
```
npm install
npx prisma migrate deploy
npm run seed
npm run build
npm start
```
Kad piše „25 Slova server radi na portu 3000“ — server radi. Ovaj prozor ostavite otvoren.

## 4. Admin panel

U drugom terminalu (jednom):
```
cd admin
npm install
npm run build
```
Otvorite http://localhost:3000/admin i prijavite se sa `ADMIN_USERNAME` / `ADMIN_PASSWORD` iz `.env` fajla.

## 5. Aplikacija u pregledaču (najlakše)

```
cd mobile
flutter pub get
flutter run -d chrome
```
Otvoriće se Chrome sa aplikacijom. Napravite nalog i probajte.

**Da biste odigrali partiju, potrebna su dva igrača:** otvorite još jedan Chrome prozor u „Incognito“ režimu
na istoj adresi (vidi se u terminalu, npr. http://localhost:54321), napravite drugi nalog,
i na oba kliknite „Igraj — nasumični protivnik“ (ili jedan napravi kod, drugi ga unese).

## 6. Aplikacija na Android telefonu (opciono)

1. Na telefonu uključite „Opcije za programere“ i „USB otklanjanje grešaka“, povežite ga kablom.
2. Telefon i računar moraju biti na istoj Wi-Fi mreži. Saznajte IP adresu računara
   (Windows: `ipconfig`, Mac: Podešavanja → Mreža), npr. 192.168.1.10.
3. ```
   cd mobile
   flutter run --dart-define=API_URL=http://192.168.1.10:3000
   ```

iPhone zahteva Mac sa Xcode-om.
