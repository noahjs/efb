import { Logger } from '@nestjs/common';

export abstract class BasePoller {
  protected readonly logger: Logger;

  constructor(name: string) {
    this.logger = new Logger(name);
  }

  /**
   * Execute the polling job.
   * @returns The number of records upserted/updated.
   */
  abstract execute(): Promise<number>;
}
