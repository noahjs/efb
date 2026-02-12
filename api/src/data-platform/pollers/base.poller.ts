import { Logger } from '@nestjs/common';

export interface PollerResult {
  recordsUpdated: number;
  errors: number;
  lastError?: string;
}

export abstract class BasePoller {
  protected readonly logger: Logger;

  constructor(name: string) {
    this.logger = new Logger(name);
  }

  /**
   * Execute the polling job.
   * @returns Result with records updated and any error info.
   */
  abstract execute(): Promise<PollerResult>;
}
