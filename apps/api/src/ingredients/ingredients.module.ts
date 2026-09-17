import { Module } from '@nestjs/common';
import { IngredientProfileGenerator } from './ingredient-profile.generator';
import { IngredientProfileQueueService } from './ingredient-profile-queue.service';
import { IngredientProfileService } from './ingredient-profile.service';

@Module({
  providers: [
    IngredientProfileGenerator,
    IngredientProfileQueueService,
    IngredientProfileService,
  ],
  exports: [IngredientProfileService],
})
export class IngredientsModule {}
