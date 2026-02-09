import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { filingConfig } from './filing.config';
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
export class LeidosService implements LeidosClient {
  private readonly logger = new Logger(LeidosService.name);
  private readonly baseUrl = filingConfig.leidosBaseUrl;

  constructor(private readonly http: HttpService) {}

  private get authHeader(): string {
    const credentials = Buffer.from(
      `${filingConfig.leidosVendorUser}:${filingConfig.leidosVendorPass}`,
    ).toString('base64');
    return `Basic ${credentials}`;
  }

  async fileFlightPlan(
    request: LeidosFileRequest,
  ): Promise<LeidosFileResponse> {
    try {
      const { data } = await firstValueFrom(
        this.http.post(`${this.baseUrl}/flightplan/file`, request, {
          headers: {
            Authorization: this.authHeader,
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }),
      );

      return {
        success: true,
        flightIdentifier: data.flightIdentifier,
        versionStamp: data.versionStamp,
        message: data.message,
      };
    } catch (error) {
      this.logger.error('Leidos file request failed', error);
      return {
        success: false,
        flightIdentifier: '',
        versionStamp: '',
        errors: [error.message || 'Failed to file flight plan with Leidos'],
      };
    }
  }

  async amendFlightPlan(
    request: LeidosAmendRequest,
  ): Promise<LeidosFileResponse> {
    try {
      const { data } = await firstValueFrom(
        this.http.post(`${this.baseUrl}/flightplan/amend`, request, {
          headers: {
            Authorization: this.authHeader,
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }),
      );

      return {
        success: true,
        flightIdentifier: data.flightIdentifier,
        versionStamp: data.versionStamp,
        message: data.message,
      };
    } catch (error) {
      this.logger.error('Leidos amend request failed', error);
      return {
        success: false,
        flightIdentifier: request.flightIdentifier,
        versionStamp: '',
        errors: [error.message || 'Failed to amend flight plan'],
      };
    }
  }

  async cancelFlightPlan(
    request: LeidosCancelRequest,
  ): Promise<LeidosFileResponse> {
    try {
      const { data } = await firstValueFrom(
        this.http.post(`${this.baseUrl}/flightplan/cancel`, request, {
          headers: {
            Authorization: this.authHeader,
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }),
      );

      return {
        success: true,
        flightIdentifier: data.flightIdentifier || request.flightIdentifier,
        versionStamp: '',
        message: data.message,
      };
    } catch (error) {
      this.logger.error('Leidos cancel request failed', error);
      return {
        success: false,
        flightIdentifier: request.flightIdentifier,
        versionStamp: '',
        errors: [error.message || 'Failed to cancel flight plan'],
      };
    }
  }

  async closeFlightPlan(
    request: LeidosCloseRequest,
  ): Promise<LeidosFileResponse> {
    try {
      const { data } = await firstValueFrom(
        this.http.post(`${this.baseUrl}/flightplan/close`, request, {
          headers: {
            Authorization: this.authHeader,
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }),
      );

      return {
        success: true,
        flightIdentifier: data.flightIdentifier || request.flightIdentifier,
        versionStamp: '',
        message: data.message,
      };
    } catch (error) {
      this.logger.error('Leidos close request failed', error);
      return {
        success: false,
        flightIdentifier: request.flightIdentifier,
        versionStamp: '',
        errors: [error.message || 'Failed to close flight plan'],
      };
    }
  }

  async getFlightPlanStatus(
    webUserName: string,
    flightIdentifier: string,
  ): Promise<LeidosStatusResponse> {
    try {
      const { data } = await firstValueFrom(
        this.http.get(`${this.baseUrl}/flightplan/status`, {
          headers: {
            Authorization: this.authHeader,
          },
          params: { webUserName, flightIdentifier },
          timeout: 30000,
        }),
      );

      return {
        flightIdentifier,
        status: data.status,
        versionStamp: data.versionStamp,
        message: data.message,
      };
    } catch (error) {
      this.logger.error('Leidos status request failed', error);
      return {
        flightIdentifier,
        status: 'error',
        message: error.message || 'Failed to get status',
      };
    }
  }
}
