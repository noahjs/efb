import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class GoogleAuthDto {
  @IsString()
  @IsNotEmpty()
  id_token: string;
}

export class AppleAuthDto {
  @IsString()
  @IsNotEmpty()
  identity_token: string;

  @IsOptional()
  @IsString()
  name?: string;
}
