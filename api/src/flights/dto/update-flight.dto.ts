import { CreateFlightDto } from './create-flight.dto';

// All fields in CreateFlightDto are already @IsOptional(),
// so UpdateFlightDto is identical.
export class UpdateFlightDto extends CreateFlightDto {}
