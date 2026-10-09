import 'reflect-metadata';
import { BadRequestException, Logger, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import * as path from 'path';
import * as fs from 'fs';
import type { NextFunction, Request, Response } from 'express';
import { AppModule } from './app.module';
import { UPLOAD_DIR } from './users/users.service';
import { ensureAdmin } from './seed-admin';
import { PrismaService } from './prisma/prisma.service';

async function bootstrap() {
  if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET nije podešen.');
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.enableCors();
  app.useBodyParser('json', { limit: '2mb' });
  app.setGlobalPrefix('api');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      // Prva poruka greške na srpskom, da je aplikacija može prikazati direktno.
      exceptionFactory: (errors) => {
        const first = errors[0];
        const msg = first?.constraints ? Object.values(first.constraints)[0] : 'Neispravni podaci.';
        return new BadRequestException(msg);
      },
    }),
  );
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  app.useStaticAssets(UPLOAD_DIR, { prefix: '/uploads' });

  // Admin panel (React build) se servira na /admin ako je izgrađen.
  const adminDist = path.resolve(process.env.ADMIN_DIST || path.join(__dirname, '..', '..', 'admin', 'dist'));
  if (fs.existsSync(adminDist)) {
    app.use((req: Request, res: Response, next: NextFunction) => {
      // Rute React aplikacije (npr. /admin/users) vraćaju index.html.
      if (req.method === 'GET' && /^\/admin(\/|$)/.test(req.path) && !path.extname(req.path)) {
        return res.sendFile(path.join(adminDist, 'index.html'));
      }
      next();
    });
    app.useStaticAssets(adminDist, { prefix: '/admin' });
  }

  await ensureAdmin(app.get(PrismaService));
  const port = Number(process.env.PORT || 3000);
  await app.listen(port, '0.0.0.0');
  Logger.log(`25 Slova server radi na portu ${port}`, 'Bootstrap');
}
void bootstrap();
