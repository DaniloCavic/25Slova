# Server + admin panel u jednoj slici (koristi je Railway, ili docker compose).
# Puna Debian slika već sadrži OpenSSL koji Prisma traži.
FROM node:22-bookworm AS base

FROM base AS admin
WORKDIR /app/admin
COPY admin/package*.json ./
RUN npm ci
COPY admin/ ./
RUN npm run build

FROM base AS backend
WORKDIR /app/backend
COPY backend/package*.json ./
COPY backend/prisma ./prisma
RUN npm ci
COPY backend/ ./
RUN npm run build

FROM base
WORKDIR /app/backend
ENV NODE_ENV=production
COPY --from=backend /app/backend ./
COPY --from=admin /app/admin/dist /app/admin/dist
EXPOSE 3000
# Pri svakom pokretanju: ažuriraj tabele, uvezi početni rečnik ako je baza prazna, pokreni server.
CMD ["sh", "-c", "npx prisma migrate deploy && npx ts-node prisma/seed.ts --if-empty && node dist/main.js"]
