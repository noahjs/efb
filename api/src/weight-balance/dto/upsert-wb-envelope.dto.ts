import {
  IsString,
  IsIn,
  IsArray,
  ValidateNested,
  IsNumber,
} from 'class-validator';
import { Type } from 'class-transformer';

class EnvelopePoint {
  @IsNumber()
  weight: number;

  @IsNumber()
  cg: number;
}

export class UpsertWBEnvelopeDto {
  @IsString()
  @IsIn(['normal', 'utility', 'aerobatic'])
  envelope_type: string;

  @IsString()
  @IsIn(['longitudinal', 'lateral'])
  axis: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EnvelopePoint)
  points: EnvelopePoint[];
}
