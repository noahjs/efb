import { IsOptional, IsString, IsIn } from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  pilot_name?: string;

  @IsOptional()
  @IsString()
  phone_number?: string;

  @IsOptional()
  @IsString()
  pilot_certificate_number?: string;

  @IsOptional()
  @IsString()
  @IsIn(['student', 'sport', 'recreational', 'private', 'commercial', 'atp'])
  pilot_certificate_type?: string;

  @IsOptional()
  @IsString()
  home_base?: string;

  @IsOptional()
  @IsString()
  leidos_username?: string;
}
