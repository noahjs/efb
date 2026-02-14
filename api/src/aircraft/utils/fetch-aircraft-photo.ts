import axios from 'axios';
import { parse as parseHTML } from 'node-html-parser';

const HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  Accept:
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
};

/**
 * Fetches the first aircraft photo URL from FlightAware for the given tail number.
 * Returns a `photos.flightaware.com` CDN URL, or null if no photo is found.
 */
export async function fetchAircraftPhoto(
  tailNumber: string,
): Promise<string | null> {
  try {
    const url = `https://www.flightaware.com/photos/aircraft/${tailNumber}`;
    const resp = await axios.get(url, {
      headers: HEADERS,
      timeout: 10000,
    });

    const root = parseHTML(resp.data);
    const images = root.querySelectorAll('img');

    for (const img of images) {
      const src = img.getAttribute('src') || '';
      if (src.includes('photos.flightaware.com/photos/')) {
        // Prefer full-size URL: replace /thumbnails/ with /midsize/ if present
        return src.replace('/thumbnails/', '/midsize/');
      }
    }

    return null;
  } catch {
    return null;
  }
}
