import { IsString, IsOptional, IsNumber, IsIn, IsInt } from 'class-validator';

export class CreateWBStationDto {
  @IsString()
  name: string;

  @IsString()
  @IsIn(['seat', 'baggage', 'fuel', 'other'])
  category: string;

  @IsNumber()
  arm: number;

  @IsOptional()
  @IsNumber()
  lateral_arm?: number;

  @IsOptional()
  @IsNumber()
  max_weight?: number;

  @IsOptional()
  @IsNumber()
  default_weight?: number;

  @IsOptional()
  @IsInt()
  fuel_tank_id?: number;

  @IsOptional()
  @IsInt()
  sort_order?: number;

  @IsOptional()
  @IsString()
  group_name?: string;
}
