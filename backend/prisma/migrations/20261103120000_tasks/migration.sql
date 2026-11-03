-- AlterEnum
ALTER TYPE "TokenTxType" ADD VALUE 'TASK_REWARD';

-- CreateTable
CREATE TABLE "DailyChallenge" (
    "userId" TEXT NOT NULL,
    "dayKey" TEXT NOT NULL,
    "words" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DailyChallenge_pkey" PRIMARY KEY ("userId","dayKey")
);

-- AddForeignKey
ALTER TABLE "DailyChallenge" ADD CONSTRAINT "DailyChallenge_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
