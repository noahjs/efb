import { PartialType } from '@nestjs/mapped-types';
import { CreateWBScenarioDto } from './create-wb-scenario.dto';

export class UpdateWBScenarioDto extends PartialType(CreateWBScenarioDto) {}
