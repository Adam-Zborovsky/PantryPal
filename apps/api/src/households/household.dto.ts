import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class JoinHouseholdDto {
  @ApiProperty({ description: 'Shareable household code.' })
  @IsString()
  @IsNotEmpty()
  code!: string;
}

export class UpdateHouseholdDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  name!: string;
}
