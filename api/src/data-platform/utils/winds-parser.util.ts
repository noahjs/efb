/**
 * Parses AWC winds aloft text data.
 * Extracted from WeatherService for reuse by the WindsAloftPoller.
 */

export interface WindsAloftAltitude {
  altitude: number;
  direction: number | null;
  speed: number | null;
  temperature: number | null;
  lightAndVariable: boolean;
}

export function parseWindsAloftText(
  rawText: string,
): Map<string, WindsAloftAltitude[]> {
  const result = new Map<string, WindsAloftAltitude[]>();
  const lines = rawText.split('\n');

  let headerIndex = -1;
  let altitudes: number[] = [];
  let colPositions: Array<{ start: number; end: number }> = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (/^\s*FT\s/.test(line) || /^\s*FT\s*3000/.test(line)) {
      headerIndex = i;
      const matches = [...line.matchAll(/\d+/g)];
      altitudes = matches.map((m) => parseInt(m[0], 10));
      colPositions = matches.map((m, idx) => {
        const start = m.index;
        const end =
          idx < matches.length - 1 ? matches[idx + 1].index : line.length + 10;
        return { start, end };
      });
      break;
    }
  }

  if (headerIndex === -1 || altitudes.length === 0) {
    return result;
  }

  for (let i = headerIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    if (line.trim().length === 0) continue;

    const stationMatch = line.match(/^([A-Z]{3})\s/);
    if (!stationMatch) continue;

    const station = stationMatch[1];
    const stationAltitudes: WindsAloftAltitude[] = [];

    for (let j = 0; j < altitudes.length; j++) {
      const alt = altitudes[j];
      const { start, end } = colPositions[j];
      const rawValue = line.substring(start, Math.min(end, line.length)).trim();
      const decoded = decodeWindValue(rawValue, alt);
      stationAltitudes.push({ altitude: alt, ...decoded });
    }

    result.set(station, stationAltitudes);
  }

  return result;
}

export function decodeWindValue(
  raw: string,
  altitude: number,
): {
  direction: number | null;
  speed: number | null;
  temperature: number | null;
  lightAndVariable: boolean;
} {
  if (!raw || raw.trim() === '') {
    return {
      direction: null,
      speed: null,
      temperature: null,
      lightAndVariable: false,
    };
  }

  if (raw.startsWith('9900')) {
    let temperature: number | null = null;
    if (raw.length > 4) {
      const tempPart = raw.substring(4);
      const tempMatch = tempPart.match(/([+-]?\d+)/);
      if (tempMatch) {
        temperature = parseInt(tempMatch[1], 10);
      }
    }
    return {
      direction: null,
      speed: null,
      temperature,
      lightAndVariable: true,
    };
  }

  if (raw.length < 4) {
    return {
      direction: null,
      speed: null,
      temperature: null,
      lightAndVariable: false,
    };
  }

  let dd = parseInt(raw.substring(0, 2), 10);
  let hh = parseInt(raw.substring(2, 4), 10);
  let temperature: number | null = null;

  if (dd >= 51 && dd <= 86) {
    dd -= 50;
    hh += 100;
  }

  const direction = dd * 10;
  const speed = hh;

  if (altitude === 3000) {
    temperature = null;
  } else if (altitude > 24000) {
    if (raw.length >= 6) {
      const tt = parseInt(raw.substring(4, 6), 10);
      temperature = -tt;
    }
  } else {
    const tempPart = raw.substring(4);
    if (tempPart.length > 0) {
      const tempMatch = tempPart.match(/([+-]?\d+)/);
      if (tempMatch) {
        temperature = parseInt(tempMatch[1], 10);
      }
    }
  }

  return { direction, speed, temperature, lightAndVariable: false };
}
