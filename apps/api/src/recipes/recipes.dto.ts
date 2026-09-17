import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';

const classifications = [
  'REQUIRED',
  'FLEXIBLE',
  'PANTRY_STAPLE',
  'GARNISH',
] as const;

export class ReviewIngredientDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  quantityMin?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  quantityMax?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  originalUnit?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  preparationNote?: string | null;

  @ApiProperty({ enum: classifications })
  @IsIn(classifications)
  classification!: (typeof classifications)[number];

  @ApiProperty()
  @IsBoolean()
  includeInShopping!: boolean;
}

export class SaveRecipeReviewDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  title!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  originalServings?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  yieldWording?: string | null;

  @ApiProperty({ type: [ReviewIngredientDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ReviewIngredientDto)
  ingredients!: ReviewIngredientDto[];

  @ApiProperty({ type: [String] })
  @IsArray()
  @IsString({ each: true })
  instructions!: string[];

  @ApiProperty()
  @IsString()
  expectedRevision!: string;
}
