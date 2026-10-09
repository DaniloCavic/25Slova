import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { User } from '@prisma/client';
import { IsString, MaxLength } from 'class-validator';
import { AdminOnly, CurrentUser } from '../common/auth.guard';
import { DictionaryService } from './dictionary.service';

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
