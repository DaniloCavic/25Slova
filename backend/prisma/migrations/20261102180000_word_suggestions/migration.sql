-- CreateEnum
CREATE TYPE "SuggestionStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED');

-- CreateTable
CREATE TABLE "WordSuggestion" (
    "id" TEXT NOT NULL,
    "word" TEXT NOT NULL,
    "length" INTEGER NOT NULL,
    "userId" TEXT NOT NULL,
    "note" TEXT,
    "status" "SuggestionStatus" NOT NULL DEFAULT 'PENDING',
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decidedAt" TIMESTAMP(3),

    CONSTRAINT "WordSuggestion_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "WordSuggestion_userId_word_key" ON "WordSuggestion"("userId", "word");

-- CreateIndex
CREATE INDEX "WordSuggestion_status_createdAt_idx" ON "WordSuggestion"("status", "createdAt");

-- CreateIndex
CREATE INDEX "WordSuggestion_word_idx" ON "WordSuggestion"("word");

-- AddForeignKey
ALTER TABLE "WordSuggestion" ADD CONSTRAINT "WordSuggestion_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
