import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsIn, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateShoppingTripDto {
  @ApiPropertyOptional({
    description: 'ISO 8601 planned shopping date and time.',
  })
  @IsOptional()
  @IsDateString()
  scheduledFor?: string;
}

export class UpdateShoppingTripDto {
  @ApiProperty({ description: 'ISO 8601 replacement shopping date and time.' })
  @IsDateString()
  scheduledFor!: string;
}

const shoppingStatuses = [
  'NEED_TO_BUY',
  'CONFIRMED_AT_HOME',
  'CHECK_AGAIN',
  'PARTIALLY_AVAILABLE',
  'PURCHASED',
  'IGNORED',
] as const;
export class UpdateShoppingItemDto {
  @ApiProperty({ enum: shoppingStatuses })
  @IsIn(shoppingStatuses)
  status!: (typeof shoppingStatuses)[number];
  @ApiPropertyOptional() @IsOptional() @IsString() knownQuantity?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() unit?: string;
}

export class CreateShoppingItemDto {
  @ApiProperty({ description: 'A household item to add to this shopping trip.' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  displayName!: string;
}
