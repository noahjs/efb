import { PartialType } from '@nestjs/mapped-types';
import { CreateWBStationDto } from './create-wb-station.dto';

export class UpdateWBStationDto extends PartialType(CreateWBStationDto) {}
