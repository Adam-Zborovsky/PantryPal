import { Module } from '@nestjs/common';
import { ActivityModule } from '../activity/activity.module';
import { AuthModule } from '../auth/auth.module';
import { HouseholdsModule } from '../households/households.module';
import { IngredientsModule } from '../ingredients/ingredients.module';
import { RecipesController } from './recipes.controller';
import { QuantityService } from './quantity.service';
import { RecipesService } from './recipes.service';

@Module({
  imports: [AuthModule, HouseholdsModule, ActivityModule, IngredientsModule],
  controllers: [RecipesController],
  providers: [QuantityService, RecipesService],
  exports: [QuantityService, RecipesService],
})
export class RecipesModule {}
