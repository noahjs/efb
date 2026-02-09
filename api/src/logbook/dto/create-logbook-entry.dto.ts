import {
  IsString,
  IsOptional,
  IsNumber,
  IsBoolean,
} from 'class-validator';

export class CreateLogbookEntryDto {
  @IsOptional()
  @IsString()
  date?: string;

  @IsOptional()
  @IsNumber()
  aircraft_id?: number;

  @IsOptional()
  @IsString()
  aircraft_identifier?: string;

  @IsOptional()
  @IsString()
  aircraft_type?: string;

  @IsOptional()
  @IsString()
  from_airport?: string;

  @IsOptional()
  @IsString()
  to_airport?: string;

  @IsOptional()
  @IsString()
  route?: string;

  @IsOptional()
  @IsNumber()
  hobbs_start?: number;

  @IsOptional()
  @IsNumber()
  hobbs_end?: number;

  @IsOptional()
  @IsNumber()
  tach_start?: number;

  @IsOptional()
  @IsNumber()
  tach_end?: number;

  @IsOptional()
  @IsString()
  time_out?: string;

  @IsOptional()
  @IsString()
  time_off?: string;

  @IsOptional()
  @IsString()
  time_on?: string;

  @IsOptional()
  @IsString()
  time_in?: string;

  @IsOptional()
  @IsNumber()
  total_time?: number;

  @IsOptional()
  @IsNumber()
  pic?: number;

  @IsOptional()
  @IsNumber()
  sic?: number;

  @IsOptional()
  @IsNumber()
  night?: number;

  @IsOptional()
  @IsNumber()
  solo?: number;

  @IsOptional()
  @IsNumber()
  cross_country?: number;

  @IsOptional()
  @IsNumber()
  distance?: number;

  @IsOptional()
  @IsNumber()
  actual_instrument?: number;

  @IsOptional()
  @IsNumber()
  simulated_instrument?: number;

  @IsOptional()
  @IsNumber()
  day_takeoffs?: number;

  @IsOptional()
  @IsNumber()
  night_takeoffs?: number;

  @IsOptional()
  @IsNumber()
  day_landings_full_stop?: number;

  @IsOptional()
  @IsNumber()
  night_landings_full_stop?: number;

  @IsOptional()
  @IsNumber()
  all_landings?: number;

  @IsOptional()
  @IsNumber()
  holds?: number;

  @IsOptional()
  @IsString()
  approaches?: string;

  @IsOptional()
  @IsNumber()
  dual_given?: number;

  @IsOptional()
  @IsNumber()
  dual_received?: number;

  @IsOptional()
  @IsNumber()
  simulated_flight?: number;

  @IsOptional()
  @IsNumber()
  ground_training?: number;

  @IsOptional()
  @IsString()
  instructor_name?: string;

  @IsOptional()
  @IsString()
  instructor_comments?: string;

  @IsOptional()
  @IsString()
  person1?: string;

  @IsOptional()
  @IsString()
  person2?: string;

  @IsOptional()
  @IsString()
  person3?: string;

  @IsOptional()
  @IsString()
  person4?: string;

  @IsOptional()
  @IsString()
  person5?: string;

  @IsOptional()
  @IsString()
  person6?: string;

  @IsOptional()
  @IsBoolean()
  flight_review?: boolean;

  @IsOptional()
  @IsBoolean()
  checkride?: boolean;

  @IsOptional()
  @IsBoolean()
  ipc?: boolean;

  @IsOptional()
  @IsString()
  comments?: string;
}
