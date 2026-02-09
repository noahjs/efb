import { IsString, IsOptional } from 'class-validator';

export class CreateEndorsementDto {
  @IsOptional()
  @IsString()
  date?: string;

  @IsOptional()
  @IsString()
  endorsement_type?: string;

  @IsOptional()
  @IsString()
  far_reference?: string;

  @IsOptional()
  @IsString()
  endorsement_text?: string;

  @IsOptional()
  @IsString()
  cfi_name?: string;

  @IsOptional()
  @IsString()
  cfi_certificate_number?: string;

  @IsOptional()
  @IsString()
  cfi_expiration_date?: string;

  @IsOptional()
  @IsString()
  expiration_date?: string;

  @IsOptional()
  @IsString()
  comments?: string;
}
