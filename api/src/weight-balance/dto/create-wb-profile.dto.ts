import { IsString, IsOptional, IsNumber, IsBoolean } from 'class-validator';

export class CreateWBProfileDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsBoolean()
  is_default?: boolean;

  @IsOptional()
  @IsString()
  datum_description?: string;

  @IsOptional()
  @IsBoolean()
  lateral_cg_enabled?: boolean;

  @IsNumber()
  empty_weight: number;

  @IsNumber()
  empty_weight_arm: number;

  @IsOptional()
  @IsNumber()
  empty_weight_moment?: number;

  @IsOptional()
  @IsNumber()
  empty_weight_lateral_arm?: number;

  @IsOptional()
  @IsNumber()
  empty_weight_lateral_moment?: number;

  @IsOptional()
  @IsNumber()
  max_ramp_weight?: number;

  @IsNumber()
  max_takeoff_weight: number;

  @IsNumber()
  max_landing_weight: number;

  @IsOptional()
  @IsNumber()
  max_zero_fuel_weight?: number;

  @IsOptional()
  @IsNumber()
  fuel_arm?: number;

  @IsOptional()
  @IsNumber()
  fuel_lateral_arm?: number;

  @IsOptional()
  @IsNumber()
  taxi_fuel_gallons?: number;

  @IsOptional()
  @IsString()
  notes?: string;
}
