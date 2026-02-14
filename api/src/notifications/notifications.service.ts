import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { DeviceToken } from './entities/device-token.entity';

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseApp: admin.app.App | null = null;

  constructor(
    @InjectRepository(DeviceToken)
    private readonly tokenRepo: Repository<DeviceToken>,
  ) {}

  async onModuleInit() {
    const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY_PATH;
    if (!keyPath) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT_KEY_PATH not set — push notifications disabled',
      );
      return;
    }

    try {
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const serviceAccount = require(
        keyPath.startsWith('/') ? keyPath : `${process.cwd()}/${keyPath}`,
      );
      this.firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      this.logger.log('Firebase Admin initialized');
    } catch (err) {
      this.logger.error(`Failed to initialize Firebase Admin: ${err.message}`);
    }
  }

  get isEnabled(): boolean {
    return this.firebaseApp !== null;
  }

  async sendToUser(
    userId: string,
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ): Promise<number> {
    if (!this.firebaseApp) return 0;

    const tokens = await this.tokenRepo.find({
      where: { user_id: userId, active: true },
    });
    if (tokens.length === 0) return 0;

    return this.sendToTokens(tokens, notification, data);
  }

  async sendToUsers(
    userIds: string[],
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ): Promise<number> {
    if (!this.firebaseApp || userIds.length === 0) return 0;

    const tokens = await this.tokenRepo
      .createQueryBuilder('dt')
      .where('dt.user_id IN (:...userIds)', { userIds })
      .andWhere('dt.active = true')
      .getMany();
    if (tokens.length === 0) return 0;

    return this.sendToTokens(tokens, notification, data);
  }

  private async sendToTokens(
    tokens: DeviceToken[],
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ): Promise<number> {
    const tokenStrings = tokens.map((t) => t.token);
    let totalSuccess = 0;

    // FCM sendEachForMulticast supports max 500 tokens per call
    for (let i = 0; i < tokenStrings.length; i += 500) {
      const batch = tokenStrings.slice(i, i + 500);
      try {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: batch,
          notification,
          data,
          apns: {
            payload: { aps: { sound: 'default' } },
          },
          android: {
            priority: 'high',
          },
        });

        totalSuccess += response.successCount;

        // Deactivate tokens that are no longer registered
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (
            resp.error &&
            (resp.error.code ===
              'messaging/registration-token-not-registered' ||
              resp.error.code === 'messaging/invalid-registration-token')
          ) {
            invalidTokens.push(batch[idx]);
          }
        });

        if (invalidTokens.length > 0) {
          await this.tokenRepo
            .createQueryBuilder()
            .update(DeviceToken)
            .set({ active: false })
            .where('token IN (:...tokens)', { tokens: invalidTokens })
            .execute();
          this.logger.log(
            `Deactivated ${invalidTokens.length} invalid device tokens`,
          );
        }
      } catch (err) {
        this.logger.error(`FCM send error: ${err.message}`);
      }
    }

    return totalSuccess;
  }
}
