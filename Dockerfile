# Server + admin panel u jednoj slici.
FROM node:22-alpine AS admin
WORKDIR /app/admin
COPY admin/package*.json ./
RUN npm ci
COPY admin/ ./
RUN npm run build

FROM node:22-alpine AS backend
WORKDIR /app/backend
COPY backend/package*.json ./
RUN npm ci
COPY backend/ ./
RUN npx prisma generate && npm run build

FROM node:22-alpine
WORKDIR /app/backend
ENV NODE_ENV=production
COPY --from=backend /app/backend ./
COPY --from=admin /app/admin/dist /app/admin/dist
EXPOSE 3000
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
