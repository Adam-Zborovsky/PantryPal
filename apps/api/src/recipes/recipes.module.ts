import { Module } from '@nestjs/common';
import { QuantityService } from './quantity.service';

@Module({ providers: [QuantityService], exports: [QuantityService] })
export class RecipesModule {}
