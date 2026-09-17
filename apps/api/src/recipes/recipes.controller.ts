import {
  Body,
  Controller,
  Get,
  Param,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AccessTokenGuard } from '../auth/access-token.guard';
import type { AuthenticatedRequest } from '../auth/auth.types';
import { SaveRecipeReviewDto } from './recipes.dto';
import { RecipesService } from './recipes.service';

@ApiTags('recipes')
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller('households/:householdId/recipes')
export class RecipesController {
  constructor(private readonly recipes: RecipesService) {}

  @Get()
  list(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
  ) {
    return this.recipes.list(request.user.sub, householdId);
  }

  @Get(':recipeId/review')
  review(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('recipeId') recipeId: string,
  ) {
    return this.recipes.review(request.user.sub, householdId, recipeId);
  }

  @Put(':recipeId/review')
  saveReview(
    @Req() request: AuthenticatedRequest,
    @Param('householdId') householdId: string,
    @Param('recipeId') recipeId: string,
    @Body() input: SaveRecipeReviewDto,
  ) {
    return this.recipes.saveReview(
      request.user.sub,
      householdId,
      recipeId,
      input,
    );
  }
}
