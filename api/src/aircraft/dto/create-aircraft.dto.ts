import {
  IsString,
  IsOptional,
  IsNumber,
  IsBoolean,
  IsIn,
} from 'class-validator';

export class CreateAircraftDto {
  @IsString()
  tail_number: string;

  @IsOptional()
  @IsString()
  call_sign?: string;

  @IsOptional()
  @IsString()
  serial_number?: string;

  @IsString()
  aircraft_type: string;

  @IsOptional()
  @IsString()
  icao_type_code?: string;

  @IsOptional()
  @IsString()
  @IsIn(['landplane', 'seaplane', 'amphibian', 'helicopter'])
  category?: string;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  home_airport?: string;

  @IsOptional()
  @IsString()
  @IsIn(['knots', 'mph'])
  airspeed_units?: string;

  @IsOptional()
  @IsString()
  @IsIn(['inches', 'centimeters'])
  length_units?: string;

  @IsOptional()
  @IsString()
  ownership_status?: string;

  @IsOptional()
  @IsString()
  @IsIn(['100ll', 'jet_a', 'mogas', 'diesel'])
  fuel_type?: string;

  @IsOptional()
  @IsNumber()
  total_usable_fuel?: number;

  @IsOptional()
  @IsNumber()
  best_glide_speed?: number;

  @IsOptional()
  @IsNumber()
  glide_ratio?: number;

  @IsOptional()
  @IsNumber()
  empty_weight?: number;

  @IsOptional()
  @IsNumber()
  max_takeoff_weight?: number;

  @IsOptional()
  @IsNumber()
  max_landing_weight?: number;

  @IsOptional()
  @IsNumber()
  fuel_weight_per_gallon?: number;

  @IsOptional()
  @IsBoolean()
  is_default?: boolean;
}
