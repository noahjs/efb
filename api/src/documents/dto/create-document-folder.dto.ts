import { IsString, IsOptional, IsNumber } from 'class-validator';

export class CreateDocumentFolderDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsNumber()
  aircraft_id?: number;
}
