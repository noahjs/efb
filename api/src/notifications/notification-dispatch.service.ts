import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, In } from 'typeorm';
import { NotificationsService } from './notifications.service';
import { NotificationLog } from './entities/notification-log.entity';
import { MetarCategoryCache } from './entities/metar-category-cache.entity';
import { User } from '../users/entities/user.entity';
import { StarredAirport } from '../users/entities/starred-airport.entity';
import { Flight } from '../flights/entities/flight.entity';
import { Airport } from '../airports/entities/airport.entity';
import { Tfr } from '../data-platform/entities/tfr.entity';
import { WeatherAlert } from '../data-platform/entities/weather-alert.entity';
import { Metar } from '../data-platform/entities/metar.entity';
import { NOTIFICATION } from '../config/constants';

/** Flight category severity order (higher = worse). */
const CATEGORY_RANK: Record<string, number> = {
  VFR: 0,
  MVFR: 1,
  IFR: 2,
  LIFR: 3,
};

interface PendingAlert {
  userId: string;
  alertType: string;
  alertKey: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class NotificationDispatchService {
  private readonly logger = new Logger(NotificationDispatchService.name);

  constructor(
    private readonly notificationsService: NotificationsService,
    @InjectRepository(NotificationLog)
    private readonly logRepo: Repository<NotificationLog>,
    @InjectRepository(MetarCategoryCache)
    private readonly metarCacheRepo: Repository<MetarCategoryCache>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(StarredAirport)
    private readonly starredRepo: Repository<StarredAirport>,
    @InjectRepository(Flight)
    private readonly flightRepo: Repository<Flight>,
    @InjectRepository(Airport)
    private readonly airportRepo: Repository<Airport>,
    @InjectRepository(Tfr)
    private readonly tfrRepo: Repository<Tfr>,
    @InjectRepository(WeatherAlert)
    private readonly weatherAlertRepo: Repository<WeatherAlert>,
    @InjectRepository(Metar)
    private readonly metarRepo: Repository<Metar>,
  ) {}

  async dispatchNewAlerts(since: Date): Promise<number> {
    if (!this.notificationsService.isEnabled) return 0;

    // Collect all users and their relevant airports
    const userAirportMap = await this.buildUserAirportMap();
    if (userAirportMap.size === 0) return 0;

    // Collect all unique airport identifiers across all users
    const allAirportIds = new Set<string>();
    for (const airports of userAirportMap.values()) {
      for (const id of airports) allAirportIds.add(id);
    }

    // Resolve airport coordinates
    const airportCoords = await this.getAirportCoords(
      Array.from(allAirportIds),
    );

    const pendingAlerts: PendingAlert[] = [];

    // 1. New TFRs
    const newTfrs = await this.tfrRepo.find({
      where: { updated_at: MoreThan(since) },
    });
    for (const tfr of newTfrs) {
      if (!tfr.geometry) continue;
      const affectedAirports = this.findAirportsInGeometry(
        airportCoords,
        tfr.geometry,
      );
      for (const [userId, userAirports] of userAirportMap) {
        const matched = affectedAirports.filter((a) =>
          userAirports.has(a),
        );
        if (matched.length === 0) continue;
        pendingAlerts.push({
          userId,
          alertType: 'tfr',
          alertKey: tfr.notam_id,
          title: 'New TFR',
          body: tfr.description ?? `TFR ${tfr.notam_id} near ${matched[0]}`,
          data: { alert_type: 'tfr', notam_id: tfr.notam_id },
        });
      }
    }

    // 2. New weather alerts
    const newAlerts = await this.weatherAlertRepo.find({
      where: { updated_at: MoreThan(since) },
    });
    for (const alert of newAlerts) {
      if (!alert.geometry) continue;
      const affectedAirports = this.findAirportsInGeometry(
        airportCoords,
        alert.geometry,
      );
      for (const [userId, userAirports] of userAirportMap) {
        const matched = affectedAirports.filter((a) =>
          userAirports.has(a),
        );
        if (matched.length === 0) continue;
        pendingAlerts.push({
          userId,
          alertType: 'weather_alert',
          alertKey: alert.alert_id,
          title: alert.event ?? 'Weather Alert',
          body: alert.headline ?? `Weather alert near ${matched[0]}`,
          data: { alert_type: 'weather_alert', alert_id: alert.alert_id },
        });
      }
    }

    // 3. METAR flight category downgrades
    const allIcaoIds = new Set<string>();
    for (const airports of userAirportMap.values()) {
      for (const id of airports) {
        // Convert FAA identifier to ICAO for METAR lookup
        const coord = airportCoords.get(id);
        if (coord?.icao) allIcaoIds.add(coord.icao);
      }
    }

    if (allIcaoIds.size > 0) {
      const metars = await this.metarRepo.find({
        where: { icao_id: In(Array.from(allIcaoIds)) },
      });

      // Build cached categories lookup
      const cachedEntries = await this.metarCacheRepo.find({
        where: { icao_id: In(Array.from(allIcaoIds)) },
      });
      const cachedMap = new Map(cachedEntries.map((c) => [c.icao_id, c]));

      // Build reverse mapping from ICAO to FAA identifier
      const icaoToFaa = new Map<string, string>();
      for (const [faaId, coord] of airportCoords) {
        if (coord.icao) icaoToFaa.set(coord.icao, faaId);
      }

      const cacheUpserts: MetarCategoryCache[] = [];

      for (const metar of metars) {
        if (!metar.flight_category) continue;

        const cached = cachedMap.get(metar.icao_id);
        const oldCategory = cached?.flight_category ?? null;
        const newCategory = metar.flight_category;

        // Update cache regardless
        const cacheEntry = new MetarCategoryCache();
        cacheEntry.icao_id = metar.icao_id;
        cacheEntry.flight_category = newCategory;
        cacheEntry.checked_at = new Date();
        cacheUpserts.push(cacheEntry);

        // Check for downgrade (higher rank = worse conditions)
        if (
          oldCategory &&
          oldCategory !== newCategory &&
          (CATEGORY_RANK[newCategory] ?? 0) > (CATEGORY_RANK[oldCategory] ?? 0)
        ) {
          const faaId = icaoToFaa.get(metar.icao_id) ?? metar.icao_id;
          const alertKey = `${metar.icao_id}:${oldCategory}->${newCategory}`;

          for (const [userId, userAirports] of userAirportMap) {
            if (!userAirports.has(faaId)) continue;
            pendingAlerts.push({
              userId,
              alertType: 'flight_category',
              alertKey,
              title: `${metar.icao_id} now ${newCategory}`,
              body: `Flight category downgraded from ${oldCategory} to ${newCategory}`,
              data: {
                alert_type: 'flight_category',
                icao_id: metar.icao_id,
                old_category: oldCategory,
                new_category: newCategory,
              },
            });
          }
        }
      }

      // Batch upsert metar category cache
      if (cacheUpserts.length > 0) {
        await this.metarCacheRepo.upsert(cacheUpserts, ['icao_id']);
      }
    }

    // Filter by user notification preferences and dedup against notification_log
    const sentCount = await this.sendFilteredAlerts(pendingAlerts);
    this.logger.log(
      `Dispatched ${sentCount} notifications (${pendingAlerts.length} candidates)`,
    );
    return sentCount;
  }

  private async buildUserAirportMap(): Promise<Map<string, Set<string>>> {
    const users = await this.userRepo.find();
    const starred = await this.starredRepo.find();

    const cutoff = new Date();
    cutoff.setHours(
      cutoff.getHours() + NOTIFICATION.ACTIVE_FLIGHT_WINDOW_HOURS,
    );
    const flights = await this.flightRepo
      .createQueryBuilder('f')
      .where('f.etd IS NOT NULL')
      .andWhere('f.user_id IS NOT NULL')
      .getMany();

    const userMap = new Map<string, Set<string>>();

    for (const user of users) {
      const airports = new Set<string>();

      // Home base
      if (user.home_base) airports.add(user.home_base);

      // Check notification prefs — skip users who disabled everything
      const prefs = user.notification_preferences;
      if (
        prefs &&
        !prefs.tfr_alerts &&
        !prefs.weather_alerts &&
        !prefs.flight_category_alerts
      ) {
        continue;
      }

      userMap.set(user.id, airports);
    }

    // Starred airports
    for (const sa of starred) {
      const airports = userMap.get(sa.user_id);
      if (airports) airports.add(sa.airport_identifier);
    }

    // Active flight airports (ETD within next 48 hours)
    for (const flight of flights) {
      if (!flight.user_id) continue;
      const airports = userMap.get(flight.user_id);
      if (!airports) continue;

      // Check if ETD is within the window
      if (flight.etd) {
        const etdDate = new Date(flight.etd);
        if (etdDate > cutoff || etdDate < new Date()) continue;
      }

      if (flight.departure_identifier) airports.add(flight.departure_identifier);
      if (flight.destination_identifier)
        airports.add(flight.destination_identifier);
      if (flight.alternate_identifier) airports.add(flight.alternate_identifier);
    }

    // Remove users with no airports
    for (const [userId, airports] of userMap) {
      if (airports.size === 0) userMap.delete(userId);
    }

    return userMap;
  }

  private async getAirportCoords(
    identifiers: string[],
  ): Promise<Map<string, { lat: number; lng: number; icao: string | null }>> {
    if (identifiers.length === 0) return new Map();

    const airports = await this.airportRepo
      .createQueryBuilder('a')
      .select([
        'a.identifier',
        'a.icao_identifier',
        'a.latitude',
        'a.longitude',
      ])
      .where('a.identifier IN (:...ids)', { ids: identifiers })
      .getMany();

    const map = new Map<
      string,
      { lat: number; lng: number; icao: string | null }
    >();
    for (const apt of airports) {
      if (apt.latitude != null && apt.longitude != null) {
        map.set(apt.identifier, {
          lat: apt.latitude,
          lng: apt.longitude,
          icao: apt.icao_identifier ?? null,
        });
      }
    }
    return map;
  }

  /**
   * Find airports whose coordinates fall within the bounding box of a GeoJSON
   * geometry, expanded by GEOMETRY_BUFFER_DEGREES.
   */
  private findAirportsInGeometry(
    airportCoords: Map<
      string,
      { lat: number; lng: number; icao: string | null }
    >,
    geometry: any,
  ): string[] {
    const bbox = this.extractBbox(geometry);
    if (!bbox) return [];

    const buffer = NOTIFICATION.GEOMETRY_BUFFER_DEGREES;
    const matched: string[] = [];

    for (const [id, coord] of airportCoords) {
      if (
        coord.lat >= bbox.minLat - buffer &&
        coord.lat <= bbox.maxLat + buffer &&
        coord.lng >= bbox.minLng - buffer &&
        coord.lng <= bbox.maxLng + buffer
      ) {
        matched.push(id);
      }
    }

    return matched;
  }

  /**
   * Extract bounding box from GeoJSON geometry coordinates.
   */
  private extractBbox(
    geometry: any,
  ): { minLat: number; maxLat: number; minLng: number; maxLng: number } | null {
    if (!geometry?.coordinates) return null;

    let minLat = 90,
      maxLat = -90,
      minLng = 180,
      maxLng = -180;

    const processCoord = (coord: number[]) => {
      const [lng, lat] = coord;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    };

    const walk = (arr: any) => {
      if (
        Array.isArray(arr) &&
        arr.length >= 2 &&
        typeof arr[0] === 'number'
      ) {
        processCoord(arr);
      } else if (Array.isArray(arr)) {
        for (const item of arr) walk(item);
      }
    };

    walk(geometry.coordinates);

    if (minLat > maxLat) return null;
    return { minLat, maxLat, minLng, maxLng };
  }

  private async sendFilteredAlerts(
    pendingAlerts: PendingAlert[],
  ): Promise<number> {
    if (pendingAlerts.length === 0) return 0;

    // Load user notification preferences
    const userIds = [...new Set(pendingAlerts.map((a) => a.userId))];
    const users = await this.userRepo.find({
      where: { id: In(userIds) },
    });
    const userPrefs = new Map(
      users.map((u) => [u.id, u.notification_preferences]),
    );

    // Check existing notification logs for dedup
    const logKeys = pendingAlerts.map(
      (a) => `${a.userId}:${a.alertType}:${a.alertKey}`,
    );
    const existingLogs = await this.logRepo
      .createQueryBuilder('nl')
      .select(['nl.user_id', 'nl.alert_type', 'nl.alert_key'])
      .where(
        pendingAlerts
          .map(
            (_, i) =>
              `(nl.user_id = :userId${i} AND nl.alert_type = :alertType${i} AND nl.alert_key = :alertKey${i})`,
          )
          .join(' OR '),
        pendingAlerts.reduce(
          (params, a, i) => ({
            ...params,
            [`userId${i}`]: a.userId,
            [`alertType${i}`]: a.alertType,
            [`alertKey${i}`]: a.alertKey,
          }),
          {},
        ),
      )
      .getMany();

    const sentSet = new Set(
      existingLogs.map(
        (l) => `${l.user_id}:${l.alert_type}:${l.alert_key}`,
      ),
    );

    let sentCount = 0;

    for (const alert of pendingAlerts) {
      // Check dedup
      const key = `${alert.userId}:${alert.alertType}:${alert.alertKey}`;
      if (sentSet.has(key)) continue;

      // Check user preferences
      const prefs = userPrefs.get(alert.userId);
      if (prefs) {
        if (alert.alertType === 'tfr' && prefs.tfr_alerts === false) continue;
        if (
          alert.alertType === 'weather_alert' &&
          prefs.weather_alerts === false
        )
          continue;
        if (
          alert.alertType === 'flight_category' &&
          prefs.flight_category_alerts === false
        )
          continue;
      }

      // Send
      const sent = await this.notificationsService.sendToUser(
        alert.userId,
        { title: alert.title, body: alert.body },
        alert.data,
      );

      if (sent > 0) {
        // Log to prevent re-sending
        await this.logRepo.save({
          user_id: alert.userId,
          alert_type: alert.alertType,
          alert_key: alert.alertKey,
          title: alert.title,
          body: alert.body,
        });
        sentSet.add(key);
        sentCount++;
      }
    }

    return sentCount;
  }
}
