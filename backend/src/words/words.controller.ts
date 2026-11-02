import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { User } from '@prisma/client';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { AdminOnly, CurrentUser } from '../common/auth.guard';
import { DictionaryService } from './dictionary.service';
import { SuggestionsService } from './suggestions.service';

class WordDto {
  @IsString()
  @MaxLength(20)
  word: string;
}

class BulkWordsDto {
  @IsString()
  @MaxLength(2_000_000)
  text: string;
}

@AdminOnly()
@Controller('admin/words')
export class AdminWordsController {
  constructor(private readonly dict: DictionaryService) {}

  @Get()
  list(
    @Query('search') search?: string,
    @Query('length') length?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.dict.list({ search, length: Number(length) || undefined, page: Number(page) || 1, pageSize: Number(pageSize) || 50 });
  }

  @Get('check')
  check(@Query('word') word: string) {
    return this.dict.check(word || '');
  }

  @Post()
  add(@Body() dto: WordDto, @CurrentUser() admin: User) {
    return this.dict.add(dto.word, admin.id);
  }

  @Post('bulk')
  bulk(@Body() dto: BulkWordsDto, @CurrentUser() admin: User) {
    return this.dict.bulkAdd(dto.text, admin.id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: WordDto) {
    return this.dict.update(id, dto.word);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.dict.remove(id);
  }
}

class SuggestDto {
  @IsString()
  @MaxLength(20)
  word: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  note?: string;
}

class RejectDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  reason?: string;
}

/** Rečnik za igrače: pregled i pretraga svih reči, predlozi novih reči. */
@Controller('dictionary')
export class DictionaryController {
  constructor(
    private readonly dict: DictionaryService,
    private readonly suggestions: SuggestionsService,
  ) {}

  @Get()
  list(@Query('search') search?: string, @Query('length') length?: string, @Query('page') page?: string) {
    const res = this.dict.publicList({ search: search?.trim().slice(0, 20), length: Number(length) || undefined, page: Number(page) || 1 });
    return { ...res, dictionarySize: this.dict.size };
  }

  @Get('check')
  check(@Query('word') word: string) {
    const r = this.dict.check(word || '');
    return { word: r.word ?? null, error: r.error ?? null, inDictionary: r.inDictionary };
  }

  @Post('suggestions')
  suggest(@CurrentUser() user: User, @Body() dto: SuggestDto) {
    return this.suggestions.suggest(user.id, dto.word, dto.note);
  }

  @Get('suggestions/mine')
  mine(@CurrentUser() user: User) {
    return this.suggestions.mine(user.id);
  }
}

@AdminOnly()
@Controller('admin/suggestions')
export class AdminSuggestionsController {
  constructor(private readonly suggestions: SuggestionsService) {}

  @Get()
  list(@Query('status') status?: string) {
    const s = (['PENDING', 'ACCEPTED', 'REJECTED'] as const).find((x) => x === status) ?? 'PENDING';
    return this.suggestions.list(s);
  }

  @Get('count')
  count() {
    return this.suggestions.pendingCount();
  }

  @Post(':id/accept')
  accept(@Param('id', new ParseUUIDPipe()) id: string, @CurrentUser() admin: User) {
    return this.suggestions.accept(id, admin.id);
  }

  @Post(':id/reject')
  reject(@Param('id', new ParseUUIDPipe()) id: string, @Body() dto: RejectDto) {
    return this.suggestions.reject(id, dto.reason);
  }
}
