import { IsOptional, IsString, IsNumber, IsIn } from 'class-validator';

export class CreateFlightDto {
  @IsOptional()
  @IsNumber()
  aircraft_id?: number;

  @IsOptional()
  @IsNumber()
  performance_profile_id?: number;

  @IsOptional()
  @IsString()
  departure_identifier?: string;

  @IsOptional()
  @IsString()
  destination_identifier?: string;

  @IsOptional()
  @IsString()
  alternate_identifier?: string;

  @IsOptional()
  @IsString()
  etd?: string;

  @IsOptional()
  @IsString()
  aircraft_identifier?: string;

  @IsOptional()
  @IsString()
  aircraft_type?: string;

  @IsOptional()
  @IsString()
  performance_profile?: string;

  @IsOptional()
  @IsNumber()
  true_airspeed?: number;

  @IsOptional()
  @IsString()
  @IsIn(['VFR', 'IFR', 'DVFR', 'SVFR'])
  flight_rules?: string;

  @IsOptional()
  @IsString()
  route_string?: string;

  @IsOptional()
  @IsNumber()
  cruise_altitude?: number;

  @IsOptional()
  @IsNumber()
  people_count?: number;

  @IsOptional()
  @IsNumber()
  avg_person_weight?: number;

  @IsOptional()
  @IsNumber()
  cargo_weight?: number;

  @IsOptional()
  @IsString()
  fuel_policy?: string;

  @IsOptional()
  @IsNumber()
  start_fuel_gallons?: number;

  @IsOptional()
  @IsNumber()
  reserve_fuel_gallons?: number;

  @IsOptional()
  @IsNumber()
  fuel_burn_rate?: number;

  @IsOptional()
  @IsNumber()
  fuel_at_shutdown_gallons?: number;

  @IsOptional()
  @IsString()
  @IsIn(['not_filed', 'filed', 'accepted', 'closed'])
  filing_status?: string;
}
