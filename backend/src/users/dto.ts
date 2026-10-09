import { Gender } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  IsDateString,
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);
const emptyToUndefined = ({ value }: { value: unknown }) =>
  typeof value === 'string' && value.trim() === '' ? undefined : typeof value === 'string' ? value.trim() : value;

export const PHONE_REGEX = /^\+?[0-9][0-9 /-]{5,19}$/;
export const PASSWORD_REGEX = /^(?=.*[A-Za-zА-Яа-яЂђЈјЉљЊњЋћЏџČčĆćŽžŠšĐđ])(?=.*\d).{8,72}$/;

/** Korisničko ime: duže od 4 znaka, dozvoljeni su svi znakovi (specifikacija 2.2). */
export class UsernameField {
  @Transform(trim)
  @IsString()
  @MinLength(5, { message: 'Korisničko ime mora imati najmanje 5 znakova.' })
  @MaxLength(20, { message: 'Korisničko ime može imati najviše 20 znakova.' })
  username: string;
}

export class ProfileFields extends UsernameField {
  @Transform(trim)
  @IsString()
  @MinLength(3, { message: 'Unesite ime i prezime.' })
  @MaxLength(60)
  fullName: string;

  @IsEnum(Gender, { message: 'Pol mora biti MALE ili FEMALE.' })
  gender: Gender;

  @IsDateString({ strict: true }, { message: 'Datum rođenja nije ispravan (YYYY-MM-DD).' })
  birthDate: string;

  @Transform(emptyToUndefined)
  @IsOptional()
  @Matches(PHONE_REGEX, { message: 'Broj telefona nije ispravan.' })
  phone?: string;
}

export class RegisterDto extends ProfileFields {
  @Transform(trim)
  @IsEmail({}, { message: 'E-mail nije ispravan.' })
  email: string;

  @Matches(PASSWORD_REGEX, {
    message: 'Lozinka mora imati najmanje 8 znakova, bar jedno slovo i bar jedan broj.',
  })
  password: string;

  @IsString()
  passwordConfirm: string;
}

export class LoginDto {
  @Transform(trim)
  @IsString()
  login: string; // korisničko ime ili e-mail

  @IsString()
  password: string;
}

export class ForgotPasswordDto {
  @Transform(trim)
  @IsEmail({}, { message: 'E-mail nije ispravan.' })
  email: string;
}

export class ResetPasswordDto extends ForgotPasswordDto {
  @Matches(/^\d{6}$/, { message: 'Kod mora imati 6 cifara.' })
  code: string;

  @Matches(PASSWORD_REGEX, {
    message: 'Lozinka mora imati najmanje 8 znakova, bar jedno slovo i bar jedan broj.',
  })
  newPassword: string;
}

export class SocialLoginDto {
  @IsString()
  idToken: string;

  @IsOptional()
  @IsString()
  fullName?: string; // Apple šalje ime samo pri prvoj prijavi
}

export class SocialCompleteDto extends ProfileFields {
  @IsString()
  socialToken: string;
}

export class UpdateProfileDto {
  @Transform(trim)
  @IsOptional()
  @IsString()
  @MinLength(5, { message: 'Korisničko ime mora imati najmanje 5 znakova.' })
  @MaxLength(20)
  username?: string;

  @Transform(trim)
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(60)
  fullName?: string;

  @IsOptional()
  @IsEnum(Gender)
  gender?: Gender;

  @IsOptional()
  @IsDateString({ strict: true })
  birthDate?: string;

  @Transform(trim)
  @IsOptional()
  @IsEmail({}, { message: 'E-mail nije ispravan.' })
  email?: string;

  @Transform(trim)
  @IsOptional()
  @ValidateIf((o) => o.phone !== '')
  @Matches(PHONE_REGEX, { message: 'Broj telefona nije ispravan.' })
  phone?: string;
}

export class ChangePasswordDto {
  @IsOptional()
  @IsString()
  currentPassword?: string;

  @Matches(PASSWORD_REGEX, {
    message: 'Lozinka mora imati najmanje 8 znakova, bar jedno slovo i bar jedan broj.',
  })
  newPassword: string;
}

export class AvatarDto {
  /** Slika kao data URL (image/jpeg ili image/png, base64), najviše ~300 KB. */
  @IsString()
  @MaxLength(400_000, { message: 'Slika je prevelika.' })
  @Matches(/^data:image\/(png|jpeg);base64,[A-Za-z0-9+/=]+$/, { message: 'Neispravan format slike.' })
  dataUrl: string;
}
