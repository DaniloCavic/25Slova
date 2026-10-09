import { Injectable, Logger } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly log = new Logger(MailService.name);
  private readonly transport = process.env.SMTP_URL ? nodemailer.createTransport(process.env.SMTP_URL) : null;

  async send(to: string, subject: string, text: string) {
    if (!this.transport) {
      // Razvojni režim: bez SMTP-a poruka se samo ispisuje u log.
      this.log.warn(`[SMTP nije podešen] Za: ${to} | ${subject}\n${text}`);
      return;
    }
    await this.transport.sendMail({ from: process.env.MAIL_FROM || 'noreply@25slova.app', to, subject, text });
  }
}
