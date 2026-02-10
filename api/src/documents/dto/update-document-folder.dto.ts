import { IsString, IsOptional } from 'class-validator';

export class UpdateDocumentFolderDto {
  @IsOptional()
  @IsString()
  name?: string;
}
