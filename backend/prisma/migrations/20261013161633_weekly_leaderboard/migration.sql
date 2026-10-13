-- AlterEnum
ALTER TYPE "MedalPeriod" ADD VALUE 'WEEK';

-- AlterTable
ALTER TABLE "PointsEvent" ADD COLUMN     "weekKey" TEXT NOT NULL DEFAULT '';

-- CreateIndex
CREATE INDEX "PointsEvent_weekKey_userId_idx" ON "PointsEvent"("weekKey", "userId");

-- Popuni nedelju za postojeće zapise (ISO nedelja po vremenu u Srbiji).
UPDATE "PointsEvent"
SET "weekKey" = to_char(("createdAt" AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/Belgrade', 'IYYY-"W"IW')
WHERE "weekKey" = '';
