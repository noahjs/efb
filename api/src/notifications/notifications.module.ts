import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsService } from './notifications.service';
import { NotificationDispatchService } from './notification-dispatch.service';
import { NotificationsController } from './notifications.controller';
import { DeviceToken } from './entities/device-token.entity';
import { NotificationLog } from './entities/notification-log.entity';
import { MetarCategoryCache } from './entities/metar-category-cache.entity';
import { User } from '../users/entities/user.entity';
import { StarredAirport } from '../users/entities/starred-airport.entity';
import { Flight } from '../flights/entities/flight.entity';
import { Airport } from '../airports/entities/airport.entity';
import { Tfr } from '../data-platform/entities/tfr.entity';
import { WeatherAlert } from '../data-platform/entities/weather-alert.entity';
import { Metar } from '../data-platform/entities/metar.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      DeviceToken,
      NotificationLog,
      MetarCategoryCache,
      User,
      StarredAirport,
      Flight,
      Airport,
      Tfr,
      WeatherAlert,
      Metar,
    ]),
  ],
  providers: [NotificationsService, NotificationDispatchService],
  controllers: [NotificationsController],
  exports: [NotificationsService, NotificationDispatchService],
})
export class NotificationsModule {}
