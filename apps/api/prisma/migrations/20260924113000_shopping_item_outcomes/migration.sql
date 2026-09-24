ALTER TABLE "ShoppingItem"
  ADD COLUMN "manualQuantity" DECIMAL(12,3),
  ADD COLUMN "manualUnit" TEXT,
  ADD COLUMN "pickedUpAt" TIMESTAMP(3),
  ADD COLUMN "pickedUpByAccountId" TEXT,
  ADD COLUMN "archivedAt" TIMESTAMP(3),
  ADD COLUMN "archivedReason" TEXT;
