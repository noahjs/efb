import { IsString, IsOptional, IsNumber } from 'class-validator';

export class CreateFuelTankDto {
  @IsString()
  name: string;

  @IsNumber()
  capacity_gallons: number;

  @IsOptional()
  @IsNumber()
  tab_fuel_gallons?: number;

  @IsOptional()
  @IsNumber()
  sort_order?: number;
}
