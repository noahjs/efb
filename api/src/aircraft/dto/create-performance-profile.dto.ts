import { IsString, IsOptional, IsNumber, IsBoolean } from 'class-validator';

export class CreatePerformanceProfileDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsBoolean()
  is_default?: boolean;

  @IsOptional()
  @IsNumber()
  cruise_tas?: number;

  @IsOptional()
  @IsNumber()
  cruise_fuel_burn?: number;

  @IsOptional()
  @IsNumber()
  climb_rate?: number;

  @IsOptional()
  @IsNumber()
  climb_speed?: number;

  @IsOptional()
  @IsNumber()
  climb_fuel_flow?: number;

  @IsOptional()
  @IsNumber()
  descent_rate?: number;

  @IsOptional()
  @IsNumber()
  descent_speed?: number;

  @IsOptional()
  @IsNumber()
  descent_fuel_flow?: number;
}
