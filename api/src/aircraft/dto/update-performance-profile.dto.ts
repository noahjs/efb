import { PartialType } from '@nestjs/mapped-types';
import { CreatePerformanceProfileDto } from './create-performance-profile.dto';

export class UpdatePerformanceProfileDto extends PartialType(
  CreatePerformanceProfileDto,
) {}
