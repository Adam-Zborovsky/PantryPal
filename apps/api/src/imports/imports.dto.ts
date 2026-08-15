import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsString } from 'class-validator';

export class CreateImportDto {
  @ApiProperty({ enum: ['url', 'text', 'image', 'audio', 'video'] })
  @IsIn(['url', 'text', 'image', 'audio', 'video'])
  sourceKind!: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  sourceInput!: string;
}
