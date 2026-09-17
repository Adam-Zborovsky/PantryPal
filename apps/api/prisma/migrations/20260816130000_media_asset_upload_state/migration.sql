-- CreateEnum
CREATE TYPE "MediaAssetStatus" AS ENUM ('UPLOAD_PENDING', 'READY', 'EXPIRED');

-- AlterTable
ALTER TABLE "MediaAsset"
  ADD COLUMN "status" "MediaAssetStatus" NOT NULL DEFAULT 'UPLOAD_PENDING',
  ADD COLUMN "uploadedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "MediaAsset_householdId_status_expiresAt_idx"
  ON "MediaAsset"("householdId", "status", "expiresAt");
