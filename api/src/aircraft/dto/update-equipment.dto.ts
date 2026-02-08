import { IsOptional, IsString } from 'class-validator';

export class UpdateEquipmentDto {
  @IsOptional()
  @IsString()
  gps_type?: string;

  @IsOptional()
  @IsString()
  transponder_type?: string;

  @IsOptional()
  @IsString()
  adsb_compliance?: string;

  @IsOptional()
  @IsString()
  equipment_codes?: string;

  @IsOptional()
  @IsString()
  installed_avionics?: string;
}
