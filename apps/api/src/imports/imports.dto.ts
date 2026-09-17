import { ApiProperty } from '@nestjs/swagger';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateImportDto {
  @ApiProperty({ enum: ['url', 'text', 'image'] })
  @IsIn(['url', 'text', 'image'])
  sourceKind!: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200_000)
  sourceInput!: string;
}

export class CreateMediaUploadDto {
  @ApiProperty({ enum: ['image'] })
  @IsIn(['image'])
  kind!: string;

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

export class MediaUploadResponseDto {
  @ApiProperty()
  assetId!: string;

  @ApiProperty({
    description: 'Short-lived signed PUT URL. Treat as a secret.',
  })
  uploadUrl!: string;

  @ApiProperty({ format: 'date-time' })
  uploadExpiresAt!: Date;

  @ApiProperty({ format: 'date-time' })
  assetExpiresAt!: Date;
}

export class CompleteMediaUploadResponseDto {
  @ApiProperty()
  assetId!: string;

  @ApiProperty({ enum: ['READY'] })
  status!: 'READY';

  @ApiProperty()
  byteSize!: number;
}
