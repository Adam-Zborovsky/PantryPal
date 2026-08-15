import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsIn, IsNotEmpty, IsOptional, IsString, Matches, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'alex@example.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({ minLength: 12, example: 'correct-horse-battery-staple' })
  @MinLength(12)
  password!: string;

  @ApiProperty({ example: 'Alex' })
  @IsString()
  @IsNotEmpty()
  displayName!: string;

  @ApiProperty({ description: 'One-time operator beta invite.' })
  @IsString()
  @IsNotEmpty()
  betaInvite!: string;

  @ApiProperty({ example: 'The Martins' })
  @IsString()
  @IsNotEmpty()
  householdName!: string;

  @ApiPropertyOptional({ example: 'Asia/Jerusalem', default: 'UTC' })
  @IsOptional()
  @IsString()
  timezone?: string;

  @ApiPropertyOptional({ enum: ['web', 'android'], default: 'web' })
  @IsOptional()
  @IsIn(['web', 'android'])
  client?: 'web' | 'android';
}

export class LoginDto {
  @ApiProperty({ example: 'alex@example.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({ minLength: 12 })
  @MinLength(12)
  password!: string;

  @ApiPropertyOptional({ enum: ['web', 'android'], default: 'web' })
  @IsOptional()
  @IsIn(['web', 'android'])
  client?: 'web' | 'android';
}

export class RefreshDto {
  @ApiPropertyOptional({ description: 'Android-only refresh credential.' })
  @IsOptional()
  @IsString()
  refreshToken?: string;

  @ApiPropertyOptional({ enum: ['web', 'android'], default: 'web' })
  @IsOptional()
  @IsIn(['web', 'android'])
  client?: 'web' | 'android';
}

export class AccountResponseDto {
  @ApiProperty() id!: string;
  @ApiProperty() email!: string;
  @ApiProperty() displayName!: string;
}

export class HouseholdResponseDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiProperty() timezone!: string;
}

export class AuthSessionResponseDto {
  @ApiProperty() accessToken!: string;
  @ApiPropertyOptional({ description: 'Returned only to Android clients.' }) refreshToken?: string;
  @ApiPropertyOptional({ type: AccountResponseDto }) account?: AccountResponseDto;
  @ApiPropertyOptional({ type: HouseholdResponseDto }) household?: HouseholdResponseDto;
  @ApiPropertyOptional({ description: 'Returned only immediately after registration.' }) householdCode?: string;
}

export class CreateBetaInviteDto {
  @ApiPropertyOptional({ example: 14 })
  @IsOptional()
  @Matches(/^\d+$/)
  expiresInDays?: string;
}

export class PasswordResetDto {
  @ApiProperty({ minLength: 12 })
  @MinLength(12)
  password!: string;
}
