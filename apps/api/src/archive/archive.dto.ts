import { ApiProperty } from '@nestjs/swagger';
import {
  IsInt,
  IsNotEmpty,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateCoverUploadDto {
  @ApiProperty({ example: 'image/jpeg' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  mimeType!: string;

  @ApiProperty({
    description: 'Exact client-side byte count.',
    example: 524288,
  })
  @IsInt()
  @Min(1)
  byteSize!: number;
}

export class CompleteCoverUploadDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  assetId!: string;
}
