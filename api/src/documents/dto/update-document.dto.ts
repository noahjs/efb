import { IsString, IsOptional, IsNumber } from 'class-validator';

export class UpdateDocumentDto {
  @IsOptional()
  @IsString()
  original_name?: string;

  @IsOptional()
  @IsNumber()
  folder_id?: number | null;

  @IsOptional()
  @IsNumber()
  aircraft_id?: number | null;
}
