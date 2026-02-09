import { IsString, IsOptional } from 'class-validator';

export class CreateCertificateDto {
  @IsOptional()
  @IsString()
  certificate_type?: string;

  @IsOptional()
  @IsString()
  certificate_class?: string;

  @IsOptional()
  @IsString()
  certificate_number?: string;

  @IsOptional()
  @IsString()
  issue_date?: string;

  @IsOptional()
  @IsString()
  expiration_date?: string;

  @IsOptional()
  @IsString()
  ratings?: string;

  @IsOptional()
  @IsString()
  limitations?: string;

  @IsOptional()
  @IsString()
  comments?: string;
}
