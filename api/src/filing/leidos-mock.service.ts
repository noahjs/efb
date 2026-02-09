import { Injectable, Logger } from '@nestjs/common';
import {
  LeidosClient,
  LeidosFileRequest,
  LeidosFileResponse,
  LeidosAmendRequest,
  LeidosCancelRequest,
  LeidosCloseRequest,
  LeidosStatusResponse,
} from './interfaces/leidos-types';

@Injectable()
export class LeidosMockService implements LeidosClient {
  private readonly logger = new Logger(LeidosMockService.name);
  private counter = 1000;
  private plans = new Map<string, { status: string; versionStamp: string }>();

  async fileFlightPlan(
    request: LeidosFileRequest,
  ): Promise<LeidosFileResponse> {
    this.logger.log(
      `[MOCK] Filing flight plan for ${request.flightPlan.aircraftIdentifier} ` +
        `${request.flightPlan.departurePoint}-${request.flightPlan.destinationPoint}`,
    );

    // Simulate network delay
    await this.delay(800);

    const flightIdentifier = `FP${++this.counter}`;
    const versionStamp = `v${Date.now()}`;

    this.plans.set(flightIdentifier, {
      status: 'filed',
      versionStamp,
    });

    return {
      success: true,
      flightIdentifier,
      versionStamp,
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
      };
    }

    const versionStamp = `v${Date.now()}`;
    plan.versionStamp = versionStamp;

    return {
      success: true,
      flightIdentifier: request.flightIdentifier,
      versionStamp,
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
    if (plan) {
      plan.status = 'cancelled';
    }

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
    if (plan) {
      plan.status = 'closed';
    }

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

    return {
      flightIdentifier,
      status: plan?.status ?? 'unknown',
      versionStamp: plan?.versionStamp,
      message: `[MOCK] Status retrieved`,
    };
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
