import { Injectable, Logger } from '@nestjs/common';
import {
  LeidosClient,
  LeidosFileRequest,
  LeidosFileResponse,
  LeidosAmendRequest,
  LeidosCancelRequest,
  LeidosCloseRequest,
  LeidosStatusResponse,
  LeidosFlightPlanPayload,
  LeidosCodedMessage,
} from './interfaces/leidos-types';

interface StoredPlan {
  currentState: string;
  versionStamp: string;
  flightPlan: LeidosFlightPlanPayload;
  beaconCode: string;
}

@Injectable()
export class LeidosMockService implements LeidosClient {
  private readonly logger = new Logger(LeidosMockService.name);
  private counter = 1000;
  private plans = new Map<string, StoredPlan>();

  async fileFlightPlan(
    request: LeidosFileRequest,
  ): Promise<LeidosFileResponse> {
    this.logger.log(
      `[MOCK] Filing flight plan for ${request.flightPlan.aircraftIdentifier} ` +
        `${request.flightPlan.departurePoint}-${request.flightPlan.destinationPoint}`,
    );

    // Simulate network delay
    await this.delay(800);

    // Basic validation
    const errors = this.validatePayload(request.flightPlan);
    if (errors.length > 0) {
      return {
        success: false,
        flightIdentifier: '',
        versionStamp: '',
        errors: errors.map((e) => e.message),
        returnCodedMessage: errors,
      };
    }

    const now = new Date();
    const seq = ++this.counter;
    const flightIdentifier = this.formatIdentifier(seq, now);
    const versionStamp = this.formatVersionStamp(now);
    const beaconCode = this.generateBeaconCode(request.flightPlan.flightType);

    this.plans.set(flightIdentifier, {
      currentState: 'PROPOSED',
      versionStamp,
      flightPlan: { ...request.flightPlan },
      beaconCode,
    });

    return {
      success: true,
      flightIdentifier,
      versionStamp,
      beaconCode,
      message: `[MOCK] Flight plan ${flightIdentifier} filed successfully`,
    };
  }

  async amendFlightPlan(
    request: LeidosAmendRequest,
  ): Promise<LeidosFileResponse> {
    this.logger.log(`[MOCK] Amending flight plan ${request.flightIdentifier}`);

    await this.delay(600);

    const plan = this.plans.get(request.flightIdentifier);
    if (!plan) {
      return {
        success: false,
        flightIdentifier: request.flightIdentifier,
        versionStamp: '',
        errors: ['Flight plan not found'],
        returnCodedMessage: [
          { code: 'FP_NOT_FOUND', message: 'Flight plan not found' },
        ],
      };
    }

    // Basic validation on the amended payload
    const errors = this.validatePayload(request.flightPlan);
    if (errors.length > 0) {
      return {
        success: false,
        flightIdentifier: request.flightIdentifier,
        versionStamp: plan.versionStamp,
        errors: errors.map((e) => e.message),
        returnCodedMessage: errors,
      };
    }

    const now = new Date();
    const versionStamp = this.formatVersionStamp(now);
    plan.versionStamp = versionStamp;
    plan.flightPlan = { ...request.flightPlan };
    // State stays PROPOSED after amend

    return {
      success: true,
      flightIdentifier: request.flightIdentifier,
      versionStamp,
      beaconCode: plan.beaconCode,
      message: `[MOCK] Flight plan ${request.flightIdentifier} amended successfully`,
    };
  }

  async cancelFlightPlan(
    request: LeidosCancelRequest,
  ): Promise<LeidosFileResponse> {
    this.logger.log(
      `[MOCK] Cancelling flight plan ${request.flightIdentifier}`,
    );

    await this.delay(400);

    const plan = this.plans.get(request.flightIdentifier);
    if (!plan) {
      return {
        success: false,
        flightIdentifier: request.flightIdentifier,
        versionStamp: '',
        errors: ['Flight plan not found'],
        returnCodedMessage: [
          { code: 'FP_NOT_FOUND', message: 'Flight plan not found' },
        ],
      };
    }

    plan.currentState = 'CANCELLED';

    return {
      success: true,
      flightIdentifier: request.flightIdentifier,
      versionStamp: '',
      message: `[MOCK] Flight plan ${request.flightIdentifier} cancelled`,
    };
  }

  async closeFlightPlan(
    request: LeidosCloseRequest,
  ): Promise<LeidosFileResponse> {
    this.logger.log(`[MOCK] Closing flight plan ${request.flightIdentifier}`);

    await this.delay(400);

    const plan = this.plans.get(request.flightIdentifier);
    if (!plan) {
      return {
        success: false,
        flightIdentifier: request.flightIdentifier,
        versionStamp: '',
        errors: ['Flight plan not found'],
        returnCodedMessage: [
          { code: 'FP_NOT_FOUND', message: 'Flight plan not found' },
        ],
      };
    }

    plan.currentState = 'CLOSED';

    return {
      success: true,
      flightIdentifier: request.flightIdentifier,
      versionStamp: '',
      message: `[MOCK] Flight plan ${request.flightIdentifier} closed`,
    };
  }

  async getFlightPlanStatus(
    webUserName: string,
    flightIdentifier: string,
  ): Promise<LeidosStatusResponse> {
    this.logger.log(`[MOCK] Checking status for ${flightIdentifier}`);

    await this.delay(300);

    const plan = this.plans.get(flightIdentifier);

    if (!plan) {
      return {
        flightIdentifier,
        status: 'unknown',
        message: '[MOCK] Flight plan not found',
      };
    }

    return {
      flightIdentifier,
      status: plan.currentState.toLowerCase(),
      versionStamp: plan.versionStamp,
      currentState: plan.currentState,
      flightPlan: { ...plan.flightPlan },
      beaconCode: plan.beaconCode,
      expectedRoute: plan.flightPlan.route,
      message: `[MOCK] Status retrieved`,
    };
  }

  private validatePayload(
    fp: LeidosFlightPlanPayload,
  ): LeidosCodedMessage[] {
    const errors: LeidosCodedMessage[] = [];
    if (!fp.aircraftIdentifier) {
      errors.push({
        code: 'MISSING_ACID',
        message: 'Aircraft identifier is required',
      });
    }
    if (!fp.departurePoint) {
      errors.push({
        code: 'MISSING_DEP',
        message: 'Departure point is required',
      });
    }
    if (!fp.destinationPoint) {
      errors.push({
        code: 'MISSING_DEST',
        message: 'Destination point is required',
      });
    }
    return errors;
  }

  private formatIdentifier(seq: number, now: Date): string {
    const y = now.getUTCFullYear();
    const mo = String(now.getUTCMonth() + 1).padStart(2, '0');
    const d = String(now.getUTCDate()).padStart(2, '0');
    const h = String(now.getUTCHours()).padStart(2, '0');
    const mi = String(now.getUTCMinutes()).padStart(2, '0');
    const s = String(now.getUTCSeconds()).padStart(2, '0');
    return `${seq}_${y}${mo}${d}_${h}${mi}${s}`;
  }

  private formatVersionStamp(now: Date): string {
    const y = now.getUTCFullYear();
    const mo = String(now.getUTCMonth() + 1).padStart(2, '0');
    const d = String(now.getUTCDate()).padStart(2, '0');
    const h = String(now.getUTCHours()).padStart(2, '0');
    const mi = String(now.getUTCMinutes()).padStart(2, '0');
    const s = String(now.getUTCSeconds()).padStart(2, '0');
    const ms = String(now.getUTCMilliseconds()).padStart(3, '0');
    return `${y}${mo}${d}${h}${mi}${s}${ms}`;
  }

  private generateBeaconCode(flightType: string): string {
    if (flightType === 'VFR') return '1200';
    // Random discrete IFR squawk: 0100-0777 range (simplified)
    const code = Math.floor(Math.random() * 4096);
    // Format as 4-digit octal-like (each digit 0-7)
    const d1 = (code >> 9) & 7;
    const d2 = (code >> 6) & 7;
    const d3 = (code >> 3) & 7;
    const d4 = code & 7;
    return `${d1}${d2}${d3}${d4}`;
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
