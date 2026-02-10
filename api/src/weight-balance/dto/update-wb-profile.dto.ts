import { PartialType } from '@nestjs/mapped-types';
import { CreateWBProfileDto } from './create-wb-profile.dto';

export class UpdateWBProfileDto extends PartialType(CreateWBProfileDto) {}
