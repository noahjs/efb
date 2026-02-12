/**
 * AirNav FBO & Fuel Price Scraper
 *
 * Scrapes FBO data and fuel prices from AirNav.com for airports in the database.
 *
 * Usage:
 *   npx ts-node -r tsconfig-paths/register src/seed/seed-fbos.ts
 *   npx ts-node -r tsconfig-paths/register src/seed/seed-fbos.ts --update-prices
 *   npx ts-node -r tsconfig-paths/register src/seed/seed-fbos.ts --airport KAPA
 */

import { DataSource, IsNull, Not } from 'typeorm';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { RunwayEnd } from '../airports/entities/runway-end.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import { Fbo } from '../fbos/entities/fbo.entity';
import { FuelPrice } from '../fbos/entities/fuel-price.entity';
import { dbConfig } from '../db.config';
import { fetchAirnavPage, parseAirportFbos } from './scrape-airnav';

const DELAY_MS = 2000;

async function main() {
  const args = process.argv.slice(2);
  const updatePricesOnly = args.includes('--update-prices');
  const singleAirportIdx = args.indexOf('--airport');
  const singleAirport =
    singleAirportIdx >= 0 ? args[singleAirportIdx + 1] : null;

  const ds = new DataSource({
    ...dbConfig,
    entities: [Airport, Runway, RunwayEnd, Frequency, Fbo, FuelPrice],
    synchronize: true,
  });

  await ds.initialize();
  console.log('Connected to database.\n');

  const airportRepo = ds.getRepository(Airport);
  const fboRepo = ds.getRepository(Fbo);
  const fuelPriceRepo = ds.getRepository(FuelPrice);

  let airports: Airport[];

  if (singleAirport) {
    // Single airport mode for testing
    const airport = await airportRepo.findOne({
      where: [
        { identifier: singleAirport },
        { icao_identifier: singleAirport },
      ],
    });
    if (!airport) {
      console.error(`Airport ${singleAirport} not found.`);
      await ds.destroy();
      process.exit(1);
    }
    airports = [airport];
  } else if (updatePricesOnly) {
    // Only re-scrape airports that already have FBOs
    airports = await airportRepo.find({
      where: { fbo_scraped_at: Not(IsNull()) },
      order: { identifier: 'ASC' },
    });
    console.log(
      `Update-prices mode: ${airports.length} airports with existing FBO data.\n`,
    );
  } else {
    // Full crawl: airports not yet scraped
    airports = await airportRepo.find({
      where: { fbo_scraped_at: IsNull() },
      order: { identifier: 'ASC' },
    });
    console.log(`Full crawl mode: ${airports.length} airports to scrape.\n`);
  }

  let scraped = 0;
  let totalFbos = 0;
  let totalPrices = 0;
  let errors = 0;
  let skipped = 0;

  for (let i = 0; i < airports.length; i++) {
    const airport = airports[i];
    const icao = airport.icao_identifier || `K${airport.identifier}`;
    const progress = `[${i + 1}/${airports.length}]`;

    try {
      const html = await fetchAirnavPage(icao);

      if (!html) {
        // 404 or no page — mark as scraped with no FBOs
        console.log(`${progress} ${icao} — no AirNav page, skipping.`);
        await airportRepo.update(airport.identifier, {
          fbo_scraped_at: new Date(),
        });
        skipped++;
        if (airports.length > 1) await sleep(500);
        continue;
      }

      const scrapedFbos = parseAirportFbos(html, icao);

      if (scrapedFbos.length === 0) {
        console.log(`${progress} ${icao} — no FBOs found.`);
        await airportRepo.update(airport.identifier, {
          fbo_scraped_at: new Date(),
        });
        skipped++;
        if (airports.length > 1) await sleep(500);
        continue;
      }

      const now = new Date();

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
          const priceData: Record<string, any> = {
            fbo_id: saved.id,
            fuel_type: fp.fuel_type,
            service_level: fp.service_level,
            price: fp.price,
            is_guaranteed: fp.is_guaranteed,
            price_date: fp.price_date,
            scraped_at: now,
          };
          await fuelPriceRepo.save(Object.assign(new FuelPrice(), priceData));
          totalPrices++;
        }
      }

      // Mark airport as scraped
      await airportRepo.update(airport.identifier, {
        fbo_scraped_at: now,
      });

      console.log(
        `${progress} ${icao} — ${scrapedFbos.length} FBOs, ${scrapedFbos.reduce((s, f) => s + f.fuel_prices.length, 0)} prices.`,
      );
      scraped++;
    } catch (err: any) {
      errors++;
      console.error(`${progress} ${icao} — ERROR: ${err.message}`);
    }

    // Rate limiting
    if (i < airports.length - 1) {
      await sleep(DELAY_MS);
    }
  }

  console.log(`\nDone!`);
  console.log(`  Scraped: ${scraped} airports`);
  console.log(`  Skipped: ${skipped} (no FBOs or no page)`);
  console.log(`  Errors: ${errors}`);
  console.log(`  Total FBOs: ${totalFbos}`);
  console.log(`  Total fuel prices: ${totalPrices}`);

  await ds.destroy();
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
