import {
  IsString,
  IsOptional,
  IsNumber,
  IsArray,
  IsInt,
} from 'class-validator';

export class CreateWBScenarioDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsInt()
  flight_id?: number;

  @IsArray()
  station_loads: { station_id: number; weight: number; occupant_name?: string }[];

  @IsOptional()
  @IsNumber()
  starting_fuel_gallons?: number;

  @IsOptional()
  @IsNumber()
  ending_fuel_gallons?: number;
}
