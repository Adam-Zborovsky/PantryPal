ALTER TABLE "ImportJob" ADD COLUMN "recipeId" TEXT;

CREATE INDEX "ImportJob_householdId_recipeId_idx" ON "ImportJob"("householdId", "recipeId");
