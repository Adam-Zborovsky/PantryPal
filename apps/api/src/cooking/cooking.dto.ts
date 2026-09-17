import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateIf,
} from 'class-validator';

const assignmentModes = ['AUTOMATIC', 'MANUAL'] as const;

export class CreateCookingInstanceDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  recipeId!: string;

  @ApiProperty({
    description: 'Desired serving count, encoded as a positive decimal.',
  })
  @IsString()
  @IsNotEmpty()
  targetServings!: string;

  @ApiPropertyOptional({
    description: 'ISO 8601 cooking date and time. Omit for Quick Cook.',
  })
  @IsOptional()
  @IsDateString()
  cookingDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  shoppingTripId?: string;

  @ApiPropertyOptional({ enum: assignmentModes, default: 'AUTOMATIC' })
  @IsOptional()
  @IsIn(assignmentModes)
  assignmentMode?: (typeof assignmentModes)[number];
}

export class RequestCookTransferDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  targetAccountId!: string;
}

export class ResolveCookTransferDto {
  @ApiProperty({
    description: 'True accepts responsibility; false declines it.',
  })
  @IsIn([true, false])
  accept!: boolean;
}

export class UpdateCookingTripDto {
  @ApiProperty({ nullable: true, type: String })
  @ValidateIf((o: UpdateCookingTripDto) => o.shoppingTripId !== null)
  @IsString()
  @IsNotEmpty()
  shoppingTripId!: string | null;
}

export class CookAgainDto {
  @ApiPropertyOptional({
    description: 'ISO 8601 cooking date and time for the new instance.',
  })
  @IsOptional()
  @IsDateString()
  cookingDate?: string;

  @ApiPropertyOptional({
    description: 'Target serving count. Defaults to the archived instance.',
  })
  @IsOptional()
  @IsString()
  targetServings?: string;
}
