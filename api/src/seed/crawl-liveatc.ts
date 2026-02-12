/**
 * LiveATC ATIS Feed Crawler
 *
 * Discovers which towered airports have ATIS feeds on LiveATC by scraping
 * search pages via ScrapingBee (LiveATC blocks direct requests with 403).
 *
 * Usage:
 *   npx ts-node -r tsconfig-paths/register src/seed/crawl-liveatc.ts
 *   npx ts-node -r tsconfig-paths/register src/seed/crawl-liveatc.ts --airport KAPA
 *   npx ts-node -r tsconfig-paths/register src/seed/crawl-liveatc.ts --resume
 */

import 'dotenv/config';
import * as fs from 'fs';
import * as path from 'path';
import { DataSource } from 'typeorm';
import { parse as parseHTML } from 'node-html-parser';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { RunwayEnd } from '../airports/entities/runway-end.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import { Fbo } from '../fbos/entities/fbo.entity';
import { FuelPrice } from '../fbos/entities/fuel-price.entity';
import { dbConfig } from '../db.config';

const DELAY_MS = 1500;
const OUTPUT_PATH = path.join(__dirname, '../../data/liveatc-feeds.json');

interface LiveAtcFeed {
  name: string;
  mount: string;
  pls_url: string;
  dedicated: boolean;
}

interface AirportFeeds {
  feeds: LiveAtcFeed[];
}

interface OutputJson {
  generated_at: string;
  airports: Record<string, AirportFeeds>;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Fetch a LiveATC search page via ScrapingBee proxy.
 */
async function fetchLiveAtcSearch(
  icao: string,
  apiKey: string,
): Promise<string | null> {
  const targetUrl = `https://www.liveatc.net/search/?icao=${icao}`;

  const url = `https://app.scrapingbee.com/api/v1/?api_key=${apiKey}&url=${encodeURIComponent(targetUrl)}&render_js=false&premium_proxy=true`;

  const response = await fetch(url, {
    signal: AbortSignal.timeout(60000),
  });

  if (response.status === 404 || response.status === 422) {
    return null;
  }

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(
      `ScrapingBee returned ${response.status} for ${icao}: ${body.substring(0, 200)}`,
    );
  }

  return response.text();
}

/**
 * Parse LiveATC search results HTML to extract ATIS feed info.
 *
 * LiveATC search pages use this structure per feed:
 *   <td bgcolor="lightblue"><strong>KAPA ATIS</strong></td>   ← section header
 *   <a href="/play/kapa1_es_atis.pls" title="...KAPA ATIS..."> ← .pls link (img inside)
 *   <a href="/archive.php?m=kapa1_es_atis">KAPA ATIS</a>      ← archive link (best name)
 *
 * Archive links have the cleanest feed names, so we use those as the
 * primary source and fill in from .pls links for any we missed.
 */
function parseFeeds(html: string, icao: string): LiveAtcFeed[] {
  const root = parseHTML(html);
  const feeds = new Map<string, LiveAtcFeed>();
  const allLinks = root.querySelectorAll('a[href]');

  // Pass 1: Archive links — best source for mount→name mapping
  // e.g., <a href="/archive.php?m=kapa1_es_atis">KAPA ATIS</a>
  for (const link of allLinks) {
    const href = link.getAttribute('href') || '';
    const match = href.match(/archive\.php\?(?:.*&)?m=([^&\s"']+)/i);
    if (!match) continue;

    const mount = match[1];
    const name = link.textContent?.trim() || `${icao} Feed`;
    feeds.set(mount, {
      name,
      mount,
      pls_url: `https://www.liveatc.net/play/${mount}.pls`,
      dedicated: isAtisOnly(name),
    });
  }

  // Pass 2: .pls links — pick up any feeds not found via archive links
  // e.g., <a href="/play/kapa1_es_atis.pls" title="...listen to KAPA ATIS...">
  for (const link of allLinks) {
    const href = link.getAttribute('href') || '';
    const match = href.match(/\/play\/([^/\s"']+)\.pls/i);
    if (!match) continue;

    const mount = match[1];
    if (feeds.has(mount)) continue;

    // The <a> wraps an <img>, so textContent is empty — use the title attr
    const title = link.getAttribute('title') || '';
    // title is like "Click here to listen to KAPA ATIS with your own player"
    const nameMatch = title.match(/listen to (.+?)(?:\s+with|\s*$)/i);
    const name = nameMatch?.[1]?.trim() || `${icao} Feed`;

    feeds.set(mount, {
      name,
      mount,
      pls_url: `https://www.liveatc.net/play/${mount}.pls`,
      dedicated: isAtisOnly(name),
    });
  }

  // Filter to only ATIS-related feeds (by name or mount point)
  const allFeeds = Array.from(feeds.values());
  const atisFeeds = allFeeds.filter(
    (f) =>
      f.name.toLowerCase().includes('atis') ||
      f.mount.toLowerCase().includes('atis'),
  );

  return atisFeeds.length > 0 ? atisFeeds : allFeeds;
}

/**
 * A feed is "dedicated" ATIS if its name contains "ATIS" but NOT combined
 * with other frequency types like "Twr", "Gnd", "App", "Dep", "Clnc".
 */
function isAtisOnly(name: string): boolean {
  const lower = name.toLowerCase();
  if (!lower.includes('atis')) return false;

  const mixedIndicators = ['twr', 'tower', 'gnd', 'ground', 'app', 'approach',
    'dep', 'departure', 'clnc', 'clearance', 'ctr', 'center'];
  return !mixedIndicators.some((ind) => lower.includes(ind));
}

/**
 * Update has_liveatc flags in database from a loaded OutputJson.
 */
async function updateDbFromJson(output: OutputJson): Promise<void> {
  console.log('\nUpdating has_liveatc flags in database...');
  const ds = new DataSource({
    ...dbConfig,
    entities: [Airport, Runway, RunwayEnd, Frequency, Fbo, FuelPrice],
  });
  await ds.initialize();

  const airportRepo = ds.getRepository(Airport);

  // Collect ICAOs with ATIS feeds and ICAOs without
  const withFeeds: string[] = [];
  const withoutFeeds: string[] = [];
  for (const [icao, data] of Object.entries(output.airports)) {
    const hasAtis = data.feeds.some(
      (f) =>
        f.name.toLowerCase().includes('atis') ||
        f.mount.toLowerCase().includes('atis'),
    );
    if (hasAtis) {
      withFeeds.push(icao);
    } else {
      withoutFeeds.push(icao);
    }
  }

  // Batch update has_liveatc = true
  const batchSize = 500;
  for (let i = 0; i < withFeeds.length; i += batchSize) {
    const batch = withFeeds.slice(i, i + batchSize);
    await airportRepo
      .createQueryBuilder()
      .update()
      .set({ has_liveatc: true })
      .where('icao_identifier IN (:...ids)', { ids: batch })
      .execute();
  }

  // Batch update has_liveatc = false
  for (let i = 0; i < withoutFeeds.length; i += batchSize) {
    const batch = withoutFeeds.slice(i, i + batchSize);
    await airportRepo
      .createQueryBuilder()
      .update()
      .set({ has_liveatc: false })
      .where('icao_identifier IN (:...ids)', { ids: batch })
      .execute();
  }

  console.log(`  Set has_liveatc = true for ${withFeeds.length} airports.`);
  console.log(`  Set has_liveatc = false for ${withoutFeeds.length} airports.`);

  await ds.destroy();
  console.log('Done!');
}

async function main() {
  const args = process.argv.slice(2);
  const singleAirportIdx = args.indexOf('--airport');
  const singleAirport =
    singleAirportIdx >= 0 ? args[singleAirportIdx + 1]?.toUpperCase() : null;
  const resume = args.includes('--resume');
  const dbOnly = args.includes('--db-only');

  // --db-only: just update the database from existing JSON, no crawling
  if (dbOnly) {
    if (!fs.existsSync(OUTPUT_PATH)) {
      console.error(`No existing data at ${OUTPUT_PATH}. Run a crawl first.`);
      process.exit(1);
    }
    const output: OutputJson = JSON.parse(fs.readFileSync(OUTPUT_PATH, 'utf-8'));
    console.log(`Loaded ${Object.keys(output.airports).length} airports from ${OUTPUT_PATH}.`);
    await updateDbFromJson(output);
    return;
  }

  const apiKey = process.env.SCRAPINGBEE_API_KEY;
  if (!apiKey) {
    console.error(
      'SCRAPINGBEE_API_KEY not set. Add it to api/.env and try again.',
    );
    process.exit(1);
  }

  // Load existing output if resuming
  let output: OutputJson = {
    generated_at: new Date().toISOString(),
    airports: {},
  };

  if (resume && fs.existsSync(OUTPUT_PATH)) {
    try {
      output = JSON.parse(fs.readFileSync(OUTPUT_PATH, 'utf-8'));
      console.log(
        `Resuming — ${Object.keys(output.airports).length} airports already crawled.\n`,
      );
    } catch {
      console.warn('Could not parse existing output file, starting fresh.\n');
    }
  }

  // Connect to DB to get towered airports
  const ds = new DataSource({
    ...dbConfig,
    entities: [Airport, Runway, RunwayEnd, Frequency, Fbo, FuelPrice],
  });
  await ds.initialize();
  console.log('Connected to database.\n');

  let airports: Airport[];

  if (singleAirport) {
    const airport = await ds.getRepository(Airport).findOne({
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
    if (!airport.icao_identifier) {
      console.error(`Airport ${singleAirport} has no ICAO identifier.`);
      await ds.destroy();
      process.exit(1);
    }
    airports = [airport];
  } else {
    // Find airports that have a TWR frequency and an ICAO identifier
    airports = await ds
      .getRepository(Airport)
      .createQueryBuilder('a')
      .innerJoin('a.frequencies', 'f', "f.type = 'TWR'")
      .where('a.icao_identifier IS NOT NULL')
      .orderBy('a.icao_identifier', 'ASC')
      .getMany();
    // Deduplicate (an airport can have multiple TWR frequencies)
    const seen = new Set<string>();
    airports = airports.filter((a) => {
      if (seen.has(a.identifier)) return false;
      seen.add(a.identifier);
      return true;
    });
    console.log(`Found ${airports.length} towered airports with ICAO codes.\n`);
  }

  await ds.destroy();

  // Filter out already-crawled airports if resuming
  if (resume && !singleAirport) {
    airports = airports.filter(
      (a) => !output.airports[a.icao_identifier!],
    );
    console.log(`${airports.length} airports remaining after resume filter.\n`);
  }

  let found = 0;
  let noFeeds = 0;
  let errors = 0;

  for (let i = 0; i < airports.length; i++) {
    const airport = airports[i];
    const icao = airport.icao_identifier!;
    const progress = `[${i + 1}/${airports.length}]`;

    try {
      const html = await fetchLiveAtcSearch(icao, apiKey);

      if (!html) {
        console.log(`${progress} ${icao} — no LiveATC page.`);
        noFeeds++;
        // Save periodically even for no-feed airports (mark them empty)
        output.airports[icao] = { feeds: [] };
      } else {
        const feeds = parseFeeds(html, icao);

        if (feeds.length === 0) {
          console.log(`${progress} ${icao} — no ATIS feeds found.`);
          noFeeds++;
          output.airports[icao] = { feeds: [] };
        } else {
          const atisFeedCount = feeds.filter(
            (f) =>
              f.name.toLowerCase().includes('atis') ||
              f.mount.toLowerCase().includes('atis'),
          ).length;
          console.log(
            `${progress} ${icao} — ${feeds.length} feed(s) found (${atisFeedCount} ATIS).`,
          );
          output.airports[icao] = { feeds };
          found++;
        }
      }

      // Save after every airport so progress isn't lost
      output.generated_at = new Date().toISOString();
      fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
      fs.writeFileSync(OUTPUT_PATH, JSON.stringify(output, null, 2) + '\n');
    } catch (err: any) {
      errors++;
      const cause = err.cause?.message ? ` (${err.cause.message})` : '';
      console.error(`${progress} ${icao} — ERROR: ${err.message}${cause}`);
    }

    // Rate limiting
    if (i < airports.length - 1) {
      await sleep(DELAY_MS);
    }
  }

  console.log(`\nCrawl complete!`);
  console.log(`  With ATIS feeds: ${found}`);
  console.log(`  No feeds: ${noFeeds}`);
  console.log(`  Errors: ${errors}`);
  console.log(`  Output: ${OUTPUT_PATH}`);

  await updateDbFromJson(output);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
