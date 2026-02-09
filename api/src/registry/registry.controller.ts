import { Controller, Get, Param } from '@nestjs/common';
import { RegistryService } from './registry.service';

@Controller('registry')
export class RegistryController {
  constructor(private readonly registryService: RegistryService) {}

  @Get('lookup/:nNumber')
  async lookup(@Param('nNumber') nNumber: string) {
    return this.registryService.lookup(nNumber);
  }
}
