import { Repository } from 'typeorm';
import { Airport } from '../../airports/entities/airport.entity';
import { Fbo } from '../../fbos/entities/fbo.entity';
import { FuelPrice } from '../../fbos/entities/fuel-price.entity';
import { fetchAirnavPage, parseAirportFbos } from '../../seed/scrape-airnav';
import { FBO } from '../../config/constants';

export interface ScrapeResult {
  fbos: number;
  prices: number;
}

/**
 * Scrape AirNav for a single airport, upsert FBOs and fuel prices.
 * Shared between FuelPricePoller (weekly) and FboPoller (monthly).
 */
export async function scrapeAndUpsertAirport(
  airport: { identifier: string; icao_identifier: string | null },
  fboRepo: Repository<Fbo>,
  fuelPriceRepo: Repository<FuelPrice>,
  airportRepo: Repository<Airport>,
): Promise<ScrapeResult> {
  const icao = airport.icao_identifier || `K${airport.identifier}`;
  const html = await fetchAirnavPage(icao);

  if (!html) {
    // No AirNav page — mark as scraped with no FBOs
    await airportRepo.update(airport.identifier, {
      fbo_scraped_at: new Date(),
    });
    return { fbos: 0, prices: 0 };
  }

  const scrapedFbos = parseAirportFbos(html, icao);

  if (scrapedFbos.length === 0) {
    await airportRepo.update(airport.identifier, {
      fbo_scraped_at: new Date(),
    });
    return { fbos: 0, prices: 0 };
  }

  const now = new Date();
  let totalFbos = 0;
  let totalPrices = 0;

  for (const scrapedFbo of scrapedFbos) {
    // Upsert FBO
    const existing = await fboRepo.findOne({
      where: {
        airport_identifier: airport.identifier,
        airnav_id: scrapedFbo.airnav_id,
      },
    });

    const fboData: Record<string, any> = {
      airport_identifier: airport.identifier,
      airnav_id: scrapedFbo.airnav_id,
      name: scrapedFbo.name,
      phone: scrapedFbo.phone,
      toll_free_phone: scrapedFbo.toll_free_phone,
      asri_frequency: scrapedFbo.asri_frequency,
      website: scrapedFbo.website,
      email: scrapedFbo.email,
      description: scrapedFbo.description,
      badges: scrapedFbo.badges,
      fuel_brand: scrapedFbo.fuel_brand,
      rating: scrapedFbo.rating,
      scraped_at: now,
    };

    let entity: Fbo;
    if (existing) {
      Object.assign(existing, fboData);
      entity = existing;
    } else {
      entity = Object.assign(new Fbo(), fboData);
    }

    const saved = await fboRepo.save(entity);
    totalFbos++;

    // Delete old fuel prices and insert new ones
    await fuelPriceRepo.delete({ fbo_id: saved.id });

    for (const fp of scrapedFbo.fuel_prices) {
      const priceEntity = Object.assign(new FuelPrice(), {
        fbo_id: saved.id,
        fuel_type: fp.fuel_type,
        service_level: fp.service_level,
        price: fp.price,
        is_guaranteed: fp.is_guaranteed,
        price_date: fp.price_date,
        scraped_at: now,
      });
      await fuelPriceRepo.save(priceEntity);
      totalPrices++;
    }
  }

  // Mark airport as scraped
  await airportRepo.update(airport.identifier, {
    fbo_scraped_at: now,
  });

  return { fbos: totalFbos, prices: totalPrices };
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
