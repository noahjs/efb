import { IsOptional, IsNumber, IsArray } from 'class-validator';

export class CalculateWBDto {
  @IsArray()
  station_loads: { station_id: number; weight: number }[];

  @IsOptional()
  @IsNumber()
  starting_fuel_gallons?: number;

  @IsOptional()
  @IsNumber()
  ending_fuel_gallons?: number;
}
