import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsString, MaxLength } from 'class-validator';

const platforms = ['android'] as const;

export class UpsertPushSubscriptionDto {
  @ApiProperty({ enum: platforms })
  @IsIn(platforms)
  platform!: (typeof platforms)[number];

  @ApiProperty({
    description: 'Firebase Cloud Messaging registration token for this device.',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  endpoint!: string;
}

export class RemovePushSubscriptionDto {
  @ApiProperty({
    description: 'Firebase Cloud Messaging registration token for this device.',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  endpoint!: string;
}
