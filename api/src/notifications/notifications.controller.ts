import {
  Controller,
  Post,
  Delete,
  Get,
  Put,
  Body,
  Param,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { DeviceToken } from './entities/device-token.entity';
import { User } from '../users/entities/user.entity';

@Controller('notifications')
export class NotificationsController {
  constructor(
    @InjectRepository(DeviceToken)
    private readonly tokenRepo: Repository<DeviceToken>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  @Post('device-token')
  async registerToken(
    @CurrentUser() user: { id: string },
    @Body() body: { token: string; platform: string },
  ) {
    await this.tokenRepo.upsert(
      {
        user_id: user.id,
        token: body.token,
        platform: body.platform,
        active: true,
      },
      ['user_id', 'token'],
    );
    return { ok: true };
  }

  @Delete('device-token/:token')
  async removeToken(
    @CurrentUser() user: { id: string },
    @Param('token') token: string,
  ) {
    await this.tokenRepo.delete({ user_id: user.id, token });
    return { ok: true };
  }

  @Get('preferences')
  async getPreferences(@CurrentUser() user: { id: string }) {
    const u = await this.userRepo.findOneBy({ id: user.id });
    return (
      u?.notification_preferences ?? {
        tfr_alerts: true,
        weather_alerts: true,
        flight_category_alerts: true,
      }
    );
  }

  @Put('preferences')
  async updatePreferences(
    @CurrentUser() user: { id: string },
    @Body()
    body: {
      tfr_alerts?: boolean;
      weather_alerts?: boolean;
      flight_category_alerts?: boolean;
    },
  ) {
    const u = await this.userRepo.findOneBy({ id: user.id });
    if (!u) return { ok: false };

    const current = u.notification_preferences ?? {
      tfr_alerts: true,
      weather_alerts: true,
      flight_category_alerts: true,
    };

    u.notification_preferences = {
      tfr_alerts: body.tfr_alerts ?? current.tfr_alerts,
      weather_alerts: body.weather_alerts ?? current.weather_alerts,
      flight_category_alerts:
        body.flight_category_alerts ?? current.flight_category_alerts,
    };

    await this.userRepo.save(u);
    return u.notification_preferences;
  }
}
