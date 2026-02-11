import { parse as parseHTML, HTMLElement } from 'node-html-parser';
import axios from 'axios';

export interface ScrapedFuelPrice {
  fuel_type: string;
  service_level: string;
  price: number;
  is_guaranteed: boolean;
  price_date: string | null;
}

export interface ScrapedFbo {
  airnav_id: string;
  name: string;
  phone: string | null;
  toll_free_phone: string | null;
  asri_frequency: string | null;
  website: string | null;
  email: string | null;
  description: string | null;
  badges: string[];
  fuel_brand: string | null;
  rating: number | null;
  fuel_prices: ScrapedFuelPrice[];
}

const HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  Accept:
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
};

export async function fetchAirnavPage(
  icao: string,
  retries = 3,
): Promise<string | null> {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const resp = await axios.get(`https://www.airnav.com/airport/${icao}`, {
        headers: HEADERS,
        timeout: 30000,
      });
      return resp.data;
    } catch (err: any) {
      const status = err.response?.status;
      if (status === 404) return null;
      if (attempt < retries && (!status || status >= 500)) {
        await sleep(2000 * attempt);
        continue;
      }
      throw err;
    }
  }
  return null;
}

export function parseAirportFbos(html: string, icao: string): ScrapedFbo[] {
  const root = parseHTML(html, { lowerCaseTagName: false });

  // Find the <A name="biz"> anchor
  const bizAnchor = root.querySelector('A[name="biz"], a[name="biz"]');
  if (!bizAnchor) return [];

  // node-html-parser flattens the TABLE structure — TRs become siblings of the anchor.
  // Walk siblings to collect FBO-section TRs (between the FBO H3 and the next H3).
  const fboRows: HTMLElement[] = [];
  let inFboSection = false;
  let sibling = bizAnchor.nextElementSibling;

  while (sibling) {
    const h3 = sibling.querySelector('H3, h3');
    if (h3) {
      const text = h3.text.trim();
      if (text.includes('FBO') || text.includes('Fuel Providers')) {
        inFboSection = true;
        sibling = sibling.nextElementSibling;
        continue;
      } else if (inFboSection) {
        // Hit the next section header — stop
        break;
      }
    }

    if (inFboSection && sibling.tagName === 'TR') {
      fboRows.push(sibling);
    }

    sibling = sibling.nextElementSibling;
  }

  // Parse individual FBO entries from the rows
  // Each FBO is in a TR that contains business data TDs
  // Separator rows have height=1
  const fbos: ScrapedFbo[] = [];

  for (const row of fboRows) {
    // Skip separator rows and header rows
    if (row.getAttribute('height') === '1') continue;
    const ths = row.querySelectorAll('TH, th');
    if (ths.length > 0) continue;

    // Look for the FBO link pattern: /airport/ICAO/FBO_ID
    const links = row.querySelectorAll('A, a');
    let airnavId: string | null = null;
    let fboName: string | null = null;

    for (const link of links) {
      const href = link.getAttribute('href') || '';
      const match = href.match(
        new RegExp(`^/airport/${icao}/([A-Za-z0-9_]+)$`),
      );
      if (match && !['update-fuel', 'reportlinks'].includes(match[1])) {
        airnavId = match[1];
        // Try to get name from img alt first, then link text
        const img = link.querySelector('IMG, img');
        if (img) {
          const alt = img.getAttribute('alt') || '';
          if (
            alt &&
            !alt.includes('1dot') &&
            !alt.includes('wing') &&
            alt.length > 1
          ) {
            // Filter out tagline images
            const src = img.getAttribute('src') || '';
            if (!src.includes('/tagline/')) {
              fboName = alt;
            }
          }
        }
        if (!fboName) {
          const text = link.text.trim();
          if (text && text.length > 1 && !text.includes('More info')) {
            fboName = text;
          }
        }
        if (fboName) break;
      }
    }

    if (!airnavId || !fboName) continue;

    // Check if we already have this FBO (duplicate rows from table structure)
    if (fbos.some((f) => f.airnav_id === airnavId)) continue;

    // Parse the TDs
    const tds = row.querySelectorAll('TD, td');

    // Contact info is typically in the 3rd or 4th TD (after business name + spacer)
    const contactTd = findContactTd(tds);
    const contact = contactTd ? parseContact(contactTd, icao, airnavId) : {};

    // Description TD
    const descTd = findDescriptionTd(tds);
    const description = descTd ? parseDescription(descTd) : null;
    const badges = descTd ? parseBadges(descTd) : [];

    // Fuel prices TD
    const fuelTd = findFuelTd(tds);
    const { fuelBrand, fuelPrices } = fuelTd
      ? parseFuelPrices(fuelTd)
      : { fuelBrand: null, fuelPrices: [] };

    // Rating from the comments TD
    const ratingTd = findRatingTd(tds);
    const rating = ratingTd ? parseRating(ratingTd) : null;

    fbos.push({
      airnav_id: airnavId,
      name: fboName,
      phone: contact.phone || null,
      toll_free_phone: contact.tollFree || null,
      asri_frequency: contact.asri || null,
      website: contact.website || null,
      email: contact.email || null,
      description,
      badges,
      fuel_brand: fuelBrand,
      rating,
      fuel_prices: fuelPrices,
    });
  }

  return fbos;
}

function findContactTd(tds: HTMLElement[]): HTMLElement | null {
  for (const td of tds) {
    const text = td.text;
    // Contact TD typically has phone numbers (digits with dashes)
    if (/\d{3}-\d{3}-\d{4}/.test(text) || /ASRI/.test(text)) {
      return td;
    }
  }
  return null;
}

function findDescriptionTd(tds: HTMLElement[]): HTMLElement | null {
  for (const td of tds) {
    const colspan = td.getAttribute('colspan');
    if (colspan === '1') return td;
    // Also check for the services/description content
    const text = td.text;
    if (
      text.length > 100 &&
      (text.includes('More info') || text.includes('Aviation'))
    ) {
      return td;
    }
  }
  return null;
}

function findFuelTd(tds: HTMLElement[]): HTMLElement | null {
  for (const td of tds) {
    const html = td.innerHTML;
    // Fuel TD contains a nested fuel table with price data or fuel brand images
    if (
      html.includes('img.airnav.com/fuel/') ||
      (html.includes('FS') && /\$\d+\.\d{2}/.test(html)) ||
      html.includes('independent')
    ) {
      return td;
    }
  }
  return null;
}

function findRatingTd(tds: HTMLElement[]): HTMLElement | null {
  for (const td of tds) {
    const html = td.innerHTML;
    if (html.includes('rating/aptpage/')) {
      return td;
    }
  }
  return null;
}

interface ContactInfo {
  phone?: string;
  tollFree?: string;
  asri?: string;
  website?: string;
  email?: string;
}

function parseContact(
  td: HTMLElement,
  icao: string,
  fboId: string,
): ContactInfo {
  const result: ContactInfo = {};
  const html = td.innerHTML;

  // ASRI frequency
  const asriMatch = html.match(/ASRI\s+([\d.]+)/);
  if (asriMatch) result.asri = asriMatch[1];

  // Phone numbers — find all phone-like patterns
  const phoneMatches = html.match(/\d{3}-\d{3}-\d{4}/g) || [];
  const lines = td.text.split(/\n|<BR>/i);

  // Check for toll-free
  const tollFreeMatch = html.match(/toll-free\s+(\d{3}-\d{3}-\d{4})/i);
  if (tollFreeMatch) result.tollFree = tollFreeMatch[1];

  // Primary phone: first phone number that isn't the toll-free
  for (const phone of phoneMatches) {
    if (phone !== result.tollFree) {
      result.phone = phone;
      break;
    }
  }

  // Website link
  const webLink = td.querySelector(
    `A[href="/airport/${icao}/${fboId}/link"], a[href="/airport/${icao}/${fboId}/link"]`,
  );
  if (webLink) {
    // The actual URL is in the onMouseover attribute
    const mouseover = webLink.getAttribute('onMouseover') || '';
    const urlMatch = mouseover.match(
      /window\.status='([^']+)'/,
    );
    if (urlMatch) result.website = urlMatch[1];
  }

  // Email
  const emailLink = td.querySelector('A[href^="mailto:"], a[href^="mailto:"]');
  if (emailLink) {
    const href = emailLink.getAttribute('href') || '';
    const emailMatch = href.match(/mailto:([^?]+)/);
    if (emailMatch) result.email = emailMatch[1];
  }

  return result;
}

function parseDescription(td: HTMLElement): string | null {
  // Get text content, clean up whitespace
  const font = td.querySelector('FONT, font');
  if (!font) return null;

  // Get text before "More info" link
  let text = font.text;
  const moreInfoIdx = text.indexOf('More info');
  if (moreInfoIdx > 0) {
    text = text.substring(0, moreInfoIdx);
  }

  text = text
    .replace(/\s+/g, ' ')
    .replace(/\u00a0/g, ' ')
    .trim();

  // Remove trailing punctuation artifacts
  text = text.replace(/\s*\.\.\.\s*$/, '...');

  return text || null;
}

function parseBadges(td: HTMLElement): string[] {
  const badges: string[] = [];
  const affLinks = td.querySelectorAll(
    'A[href*="/popup/aff.html"], a[href*="/popup/aff.html"]',
  );

  for (const link of affLinks) {
    const img = link.querySelector('IMG, img');
    if (img) {
      const alt = img.getAttribute('alt') || '';
      if (alt) badges.push(alt);
    }
  }

  return badges;
}

interface FuelParseResult {
  fuelBrand: string | null;
  fuelPrices: ScrapedFuelPrice[];
}

function parseFuelPrices(td: HTMLElement): FuelParseResult {
  const prices: ScrapedFuelPrice[] = [];
  let fuelBrand: string | null = null;
  let priceDate: string | null = null;

  // Get fuel brand from img or text
  const fuelImg = td.querySelector(
    'IMG[src*="img.airnav.com/fuel/"], img[src*="img.airnav.com/fuel/"]',
  );
  if (fuelImg) {
    fuelBrand = fuelImg.getAttribute('alt') || null;
  } else {
    // Text-only brand (e.g., "independent")
    const fuelTable = td.querySelector('table');
    if (fuelTable) {
      const firstRow = fuelTable.querySelector('TR, tr');
      if (firstRow) {
        const text = firstRow.text.trim();
        if (text && !text.includes('$') && !text.includes('FS')) {
          fuelBrand = text;
        }
      }
    }
  }

  // Find the nested fuel price table
  const fuelTable = td.querySelector('table');
  if (!fuelTable) return { fuelBrand, fuelPrices: prices };

  const rows = fuelTable.querySelectorAll('TR, tr');

  // Parse fuel types from header row (row index 1 usually has fuel type names)
  let fuelTypes: string[] = [];
  let isGuaranteed = false;

  for (const row of rows) {
    const text = row.text.trim();

    // Check for GUARANTEED
    if (text.includes('GUARANTEED')) {
      isGuaranteed = true;
      continue;
    }

    // Check for update date
    const dateMatch = text.match(/Updated\s+(\d{1,2}-[A-Za-z]{3}-\d{4})/);
    if (dateMatch) {
      priceDate = parseAirnavDate(dateMatch[1]);
      continue;
    }

    // Header row with fuel types
    const rowTds = row.querySelectorAll('TD, td');
    const rowTexts = Array.from(rowTds)
      .map((td) => td.text.trim())
      .filter(Boolean);

    if (
      rowTexts.some(
        (t) =>
          t === '100LL' || t === 'Jet A' || t === 'UL94' || t === 'MOGAS',
      )
    ) {
      fuelTypes = rowTexts.filter(
        (t) =>
          t === '100LL' ||
          t === 'Jet A' ||
          t === 'UL94' ||
          t === 'MOGAS' ||
          t === 'SAF',
      );
      continue;
    }

    // Price rows start with FS or SS
    const serviceMatch = text.match(/^(FS|SS)/);
    if (serviceMatch && fuelTypes.length > 0) {
      const serviceLevel = serviceMatch[1];
      // Extract all prices from this row
      const priceMatches = row.innerHTML.match(/\$(\d+\.\d{2})/g) || [];

      for (let i = 0; i < Math.min(priceMatches.length, fuelTypes.length); i++) {
        const priceStr = priceMatches[i].replace('$', '');
        const price = parseFloat(priceStr);
        if (!isNaN(price) && price > 0) {
          prices.push({
            fuel_type: fuelTypes[i],
            service_level: serviceLevel,
            price,
            is_guaranteed: false,
            price_date: priceDate,
          });
        }
      }
    }
  }

  // Apply guaranteed flag to all prices if found
  if (isGuaranteed) {
    for (const p of prices) {
      p.is_guaranteed = true;
    }
  }

  // Backfill price_date if it was parsed after the price rows
  if (priceDate) {
    for (const p of prices) {
      if (!p.price_date) p.price_date = priceDate;
    }
  }

  return { fuelBrand, fuelPrices: prices };
}

function parseRating(td: HTMLElement): number | null {
  const img = td.querySelector(
    'IMG[src*="rating/aptpage/"], img[src*="rating/aptpage/"]',
  );
  if (!img) return null;

  const src = img.getAttribute('src') || '';
  const match = src.match(/rating\/aptpage\/(\d+)\.gif/);
  if (!match) return null;

  const rating = parseInt(match[1], 10);
  // Rating 0 means no ratings yet
  if (rating === 0) return null;

  // AirNav uses a 1-10 scale represented as the gif filename
  return rating;
}

function parseAirnavDate(dateStr: string): string | null {
  // Format: "10-Feb-2026" -> "2026-02-10"
  const months: Record<string, string> = {
    Jan: '01',
    Feb: '02',
    Mar: '03',
    Apr: '04',
    May: '05',
    Jun: '06',
    Jul: '07',
    Aug: '08',
    Sep: '09',
    Oct: '10',
    Nov: '11',
    Dec: '12',
  };

  const parts = dateStr.split('-');
  if (parts.length !== 3) return null;

  const day = parts[0].padStart(2, '0');
  const month = months[parts[1]];
  const year = parts[2];

  if (!month) return null;
  return `${year}-${month}-${day}`;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
