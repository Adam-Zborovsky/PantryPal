-- CreateEnum
CREATE TYPE "MembershipStatus" AS ENUM ('ACTIVE', 'LEFT');

-- CreateEnum
CREATE TYPE "ImportStatus" AS ENUM ('QUEUED', 'VALIDATING_SOURCE', 'FETCHING_METADATA', 'FETCHING_CONTENT', 'ANALYZING_TEXT', 'ACQUIRING_MEDIA', 'ANALYZING_AUDIO', 'ANALYZING_VISUALS', 'STRUCTURING_RECIPE', 'READY_FOR_REVIEW', 'FAILED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "RecipeReadiness" AS ENUM ('DRAFT', 'COOK_READY', 'SHOPPING_READY', 'NEEDS_REVIEW');

-- CreateEnum
CREATE TYPE "IngredientClassification" AS ENUM ('REQUIRED', 'FLEXIBLE', 'PANTRY_STAPLE', 'GARNISH');

-- CreateEnum
CREATE TYPE "CookingStatus" AS ENUM ('SCHEDULED', 'ARCHIVED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "TransferStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "TripStatus" AS ENUM ('PROPOSED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ShoppingItemStatus" AS ENUM ('NEED_TO_BUY', 'CONFIRMED_AT_HOME', 'CHECK_AGAIN', 'PARTIALLY_AVAILABLE', 'PURCHASED', 'IGNORED');

-- CreateEnum
CREATE TYPE "MediaKind" AS ENUM ('IMAGE', 'AUDIO', 'VIDEO', 'COVER');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('IN_APP', 'ANDROID', 'WEB');

-- CreateTable
CREATE TABLE "Account" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Account_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "refreshTokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "rotatedFromId" TEXT,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BetaInvite" (
    "id" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "redeemedAt" TIMESTAMP(3),
    "redeemedByAccountId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BetaInvite_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Household" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "timezone" TEXT NOT NULL DEFAULT 'UTC',
    "revision" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Household_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HouseholdMembership" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "status" "MembershipStatus" NOT NULL DEFAULT 'ACTIVE',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leftAt" TIMESTAMP(3),

    CONSTRAINT "HouseholdMembership_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HouseholdInviteCode" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "rotatedAt" TIMESTAMP(3),
    "rotatedByAccountId" TEXT NOT NULL,

    CONSTRAINT "HouseholdInviteCode_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ActivityEvent" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "actorAccountId" TEXT NOT NULL,
    "actorDisplayName" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "summary" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ActivityEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Recipe" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "currentVersionId" TEXT,
    "title" TEXT NOT NULL,
    "readiness" "RecipeReadiness" NOT NULL DEFAULT 'DRAFT',
    "revision" INTEGER NOT NULL DEFAULT 1,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Recipe_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RecipeVersion" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "recipeId" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "originalServings" DECIMAL(12,3),
    "yieldWording" TEXT,
    "readiness" "RecipeReadiness" NOT NULL,
    "snapshot" JSONB NOT NULL,
    "createdByAccountId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RecipeVersion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RecipeSource" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "recipeId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "canonicalUrl" TEXT,
    "attribution" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RecipeSource_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CanonicalIngredient" (
    "id" TEXT NOT NULL,
    "canonicalName" TEXT NOT NULL,
    "dimension" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CanonicalIngredient_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IngredientAlias" (
    "id" TEXT NOT NULL,
    "canonicalIngredientId" TEXT NOT NULL,
    "alias" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IngredientAlias_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RecipeIngredient" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "recipeVersionId" TEXT NOT NULL,
    "canonicalIngredientId" TEXT,
    "name" TEXT NOT NULL,
    "quantityMin" DECIMAL(12,3),
    "quantityMax" DECIMAL(12,3),
    "originalUnit" TEXT,
    "normalizedUnit" TEXT,
    "originalText" TEXT NOT NULL,
    "preparationNote" TEXT,
    "classification" "IngredientClassification" NOT NULL DEFAULT 'REQUIRED',
    "includeInShopping" BOOLEAN NOT NULL DEFAULT true,
    "inferred" BOOLEAN NOT NULL DEFAULT false,
    "sortOrder" INTEGER NOT NULL,

    CONSTRAINT "RecipeIngredient_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RecipeInstruction" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "recipeVersionId" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL,

    CONSTRAINT "RecipeInstruction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ImportJob" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "status" "ImportStatus" NOT NULL DEFAULT 'QUEUED',
    "sourceKind" TEXT NOT NULL,
    "sourceInput" TEXT NOT NULL,
    "canonicalUrl" TEXT,
    "progress" INTEGER NOT NULL DEFAULT 0,
    "errorCode" TEXT,
    "errorDetail" JSONB,
    "revision" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ImportJob_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ExtractionEvidence" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "importJobId" TEXT NOT NULL,
    "fieldPath" TEXT NOT NULL,
    "origin" TEXT NOT NULL,
    "excerpt" TEXT,
    "timestampMs" INTEGER,
    "frameIndex" INTEGER,
    "confidence" DECIMAL(5,4),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ExtractionEvidence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MediaAsset" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "importJobId" TEXT,
    "kind" "MediaKind" NOT NULL,
    "storageKey" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "byteSize" INTEGER NOT NULL,
    "retained" BOOLEAN NOT NULL DEFAULT false,
    "expiresAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MediaAsset_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CookingInstance" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "recipeId" TEXT NOT NULL,
    "recipeVersionId" TEXT NOT NULL,
    "recipeSnapshot" JSONB NOT NULL,
    "scaledIngredients" JSONB NOT NULL,
    "targetServings" DECIMAL(12,3) NOT NULL,
    "cookingDate" TIMESTAMP(3),
    "shoppingTripId" TEXT,
    "assignmentMode" TEXT NOT NULL DEFAULT 'AUTOMATIC',
    "confirmedCookAccountId" TEXT NOT NULL,
    "pendingCookAccountId" TEXT,
    "status" "CookingStatus" NOT NULL DEFAULT 'SCHEDULED',
    "archiveCoverKey" TEXT,
    "archivedAt" TIMESTAMP(3),
    "revision" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CookingInstance_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CookAssignmentTransfer" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "cookingInstanceId" TEXT NOT NULL,
    "fromAccountId" TEXT NOT NULL,
    "targetAccountId" TEXT NOT NULL,
    "status" "TransferStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),

    CONSTRAINT "CookAssignmentTransfer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShoppingTrip" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "scheduledFor" TIMESTAMP(3),
    "status" "TripStatus" NOT NULL DEFAULT 'PROPOSED',
    "revision" INTEGER NOT NULL DEFAULT 1,
    "createdByAccountId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ShoppingTrip_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TripRecipeAssignment" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "shoppingTripId" TEXT NOT NULL,
    "cookingInstanceId" TEXT NOT NULL,
    "assignmentMode" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TripRecipeAssignment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShoppingItem" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "shoppingTripId" TEXT NOT NULL,
    "canonicalIngredientId" TEXT,
    "displayName" TEXT NOT NULL,
    "quantityMin" DECIMAL(12,3),
    "quantityMax" DECIMAL(12,3),
    "unit" TEXT,
    "status" "ShoppingItemStatus" NOT NULL DEFAULT 'NEED_TO_BUY',
    "revision" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ShoppingItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ShoppingItemContribution" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "shoppingItemId" TEXT NOT NULL,
    "cookingInstanceId" TEXT NOT NULL,
    "recipeTitle" TEXT NOT NULL,
    "quantityMin" DECIMAL(12,3),
    "quantityMax" DECIMAL(12,3),
    "unit" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ShoppingItemContribution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PantryAssessment" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "shoppingItemId" TEXT NOT NULL,
    "status" "ShoppingItemStatus" NOT NULL,
    "confirmedByAccountId" TEXT NOT NULL,
    "knownQuantity" DECIMAL(12,3),
    "unit" TEXT,
    "demandAtConfirmation" JSONB NOT NULL,
    "horizonEnd" TIMESTAMP(3),
    "staleAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PantryAssessment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "householdId" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "channel" "NotificationChannel" NOT NULL DEFAULT 'IN_APP',
    "dedupeKey" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "deepLink" TEXT NOT NULL,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PushSubscription" (
    "id" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "endpoint" TEXT NOT NULL,
    "keys" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PushSubscription_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Account_email_key" ON "Account"("email");

-- CreateIndex
CREATE INDEX "Session_accountId_expiresAt_idx" ON "Session"("accountId", "expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "BetaInvite_tokenHash_key" ON "BetaInvite"("tokenHash");

-- CreateIndex
CREATE INDEX "HouseholdMembership_accountId_status_idx" ON "HouseholdMembership"("accountId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "HouseholdMembership_householdId_accountId_key" ON "HouseholdMembership"("householdId", "accountId");

-- CreateIndex
CREATE UNIQUE INDEX "HouseholdInviteCode_codeHash_key" ON "HouseholdInviteCode"("codeHash");

-- CreateIndex
CREATE INDEX "HouseholdInviteCode_householdId_idx" ON "HouseholdInviteCode"("householdId");

-- CreateIndex
CREATE INDEX "ActivityEvent_householdId_createdAt_idx" ON "ActivityEvent"("householdId", "createdAt");

-- CreateIndex
CREATE INDEX "Recipe_householdId_updatedAt_idx" ON "Recipe"("householdId", "updatedAt");

-- CreateIndex
CREATE INDEX "RecipeVersion_householdId_recipeId_idx" ON "RecipeVersion"("householdId", "recipeId");

-- CreateIndex
CREATE UNIQUE INDEX "RecipeVersion_recipeId_version_key" ON "RecipeVersion"("recipeId", "version");

-- CreateIndex
CREATE INDEX "RecipeSource_householdId_recipeId_idx" ON "RecipeSource"("householdId", "recipeId");

-- CreateIndex
CREATE UNIQUE INDEX "CanonicalIngredient_canonicalName_key" ON "CanonicalIngredient"("canonicalName");

-- CreateIndex
CREATE UNIQUE INDEX "IngredientAlias_alias_key" ON "IngredientAlias"("alias");

-- CreateIndex
CREATE INDEX "RecipeIngredient_householdId_recipeVersionId_idx" ON "RecipeIngredient"("householdId", "recipeVersionId");

-- CreateIndex
CREATE INDEX "RecipeInstruction_householdId_recipeVersionId_idx" ON "RecipeInstruction"("householdId", "recipeVersionId");

-- CreateIndex
CREATE INDEX "ImportJob_householdId_createdAt_idx" ON "ImportJob"("householdId", "createdAt");

-- CreateIndex
CREATE INDEX "ExtractionEvidence_importJobId_idx" ON "ExtractionEvidence"("importJobId");

-- CreateIndex
CREATE INDEX "MediaAsset_householdId_expiresAt_idx" ON "MediaAsset"("householdId", "expiresAt");

-- CreateIndex
CREATE INDEX "CookingInstance_householdId_cookingDate_idx" ON "CookingInstance"("householdId", "cookingDate");

-- CreateIndex
CREATE INDEX "CookAssignmentTransfer_householdId_cookingInstanceId_idx" ON "CookAssignmentTransfer"("householdId", "cookingInstanceId");

-- CreateIndex
CREATE INDEX "ShoppingTrip_householdId_scheduledFor_idx" ON "ShoppingTrip"("householdId", "scheduledFor");

-- CreateIndex
CREATE UNIQUE INDEX "TripRecipeAssignment_shoppingTripId_cookingInstanceId_key" ON "TripRecipeAssignment"("shoppingTripId", "cookingInstanceId");

-- CreateIndex
CREATE INDEX "ShoppingItem_householdId_shoppingTripId_idx" ON "ShoppingItem"("householdId", "shoppingTripId");

-- CreateIndex
CREATE INDEX "ShoppingItemContribution_shoppingItemId_idx" ON "ShoppingItemContribution"("shoppingItemId");

-- CreateIndex
CREATE INDEX "PantryAssessment_householdId_shoppingItemId_idx" ON "PantryAssessment"("householdId", "shoppingItemId");

-- CreateIndex
CREATE INDEX "Notification_householdId_accountId_createdAt_idx" ON "Notification"("householdId", "accountId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Notification_accountId_channel_dedupeKey_key" ON "Notification"("accountId", "channel", "dedupeKey");

-- CreateIndex
CREATE UNIQUE INDEX "PushSubscription_endpoint_key" ON "PushSubscription"("endpoint");

-- CreateIndex
CREATE INDEX "PushSubscription_accountId_idx" ON "PushSubscription"("accountId");

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "Account"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HouseholdMembership" ADD CONSTRAINT "HouseholdMembership_householdId_fkey" FOREIGN KEY ("householdId") REFERENCES "Household"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HouseholdMembership" ADD CONSTRAINT "HouseholdMembership_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "Account"("id") ON DELETE CASCADE ON UPDATE CASCADE;
