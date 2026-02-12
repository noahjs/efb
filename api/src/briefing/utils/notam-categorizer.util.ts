import {
  BriefingNotam,
  CategorizedNotams,
  EnrouteNotams,
} from '../interfaces/briefing-response.interface';
import { BRIEFING } from '../../config/constants';

// Maps NOTAM keyword/type field to a category bucket
const KEYWORD_CATEGORY_MAP: Record<string, string> = {
  NAV: 'navigation',
  COM: 'communication',
  SVC: 'svc',
  AIRSPACE: 'airspace',
  SUA: 'specialUseAirspace',
  RWY: 'rwyTwyApronAdFdc',
  TWY: 'rwyTwyApronAdFdc',
  APRON: 'rwyTwyApronAdFdc',
  AD: 'rwyTwyApronAdFdc',
  FDC: 'rwyTwyApronAdFdc',
  IAP: 'rwyTwyApronAdFdc',
  SID: 'rwyTwyApronAdFdc',
  STAR: 'rwyTwyApronAdFdc',
  ODP: 'rwyTwyApronAdFdc',
  OBST: 'obstruction',
};

/**
 * Categorize a single NOTAM by its keyword/type field.
 */
export function categorizeNotam(keyword: string): string {
  const upper = (keyword || '').toUpperCase().trim();
  return KEYWORD_CATEGORY_MAP[upper] || 'other';
}

/**
 * Check if a NOTAM indicates a closure or unsafe condition.
 */
export function isClosureNotam(text: string): boolean {
  const upper = (text || '').toUpperCase();
  return BRIEFING.NOTAM_CLOSURE_KEYWORDS.some((kw) => upper.includes(kw));
}

/**
 * Parse a raw NOTAM response into a BriefingNotam.
 */
export function parseNotam(raw: any, icaoId: string): BriefingNotam {
  return {
    id: raw.notamNumber || raw.id || '',
    type: raw.keyword || raw.type || '',
    icaoId,
    text: raw.traditionalMessageFrom4thWord || raw.text || '',
    fullText: raw.traditionalMessage || raw.fullText || raw.text || '',
    effectiveStart: raw.startDate || raw.effectiveStart || null,
    effectiveEnd: raw.endDate || raw.effectiveEnd || null,
    category: categorizeNotam(raw.keyword || raw.type || ''),
  };
}

/**
 * Categorize a list of NOTAMs for departure/destination (4 buckets).
 */
export function categorizeNotamList(
  notams: BriefingNotam[],
): CategorizedNotams {
  const result: CategorizedNotams = {
    navigation: [],
    communication: [],
    svc: [],
    obstruction: [],
  };

  for (const notam of notams) {
    const cat = notam.category;
    if (cat === 'navigation') result.navigation.push(notam);
    else if (cat === 'communication') result.communication.push(notam);
    else if (cat === 'svc') result.svc.push(notam);
    else if (cat === 'obstruction') result.obstruction.push(notam);
    // Other categories go to svc as catch-all for dep/dest
    else result.svc.push(notam);
  }

  return result;
}

/**
 * Categorize a list of NOTAMs for enroute (7 buckets).
 */
export function categorizeEnrouteNotams(
  notams: BriefingNotam[],
): EnrouteNotams {
  const result: EnrouteNotams = {
    navigation: [],
    communication: [],
    svc: [],
    airspace: [],
    specialUseAirspace: [],
    rwyTwyApronAdFdc: [],
    otherUnverified: [],
  };

  for (const notam of notams) {
    const cat = notam.category;
    if (cat === 'navigation') result.navigation.push(notam);
    else if (cat === 'communication') result.communication.push(notam);
    else if (cat === 'svc') result.svc.push(notam);
    else if (cat === 'airspace') result.airspace.push(notam);
    else if (cat === 'specialUseAirspace')
      result.specialUseAirspace.push(notam);
    else if (cat === 'rwyTwyApronAdFdc') result.rwyTwyApronAdFdc.push(notam);
    else result.otherUnverified.push(notam);
  }

  return result;
}
