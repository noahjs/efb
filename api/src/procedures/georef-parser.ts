import {
  PDFDocument,
  PDFArray,
  PDFDict,
  PDFName,
  PDFNumber,
  PDFString,
  PDFHexString,
} from 'pdf-lib';

export interface GeorefData {
  bbox: [number, number, number, number]; // x1, y1, x2, y2 in PDF points
  gpts: [number, number][]; // [[lat, lng], ...] — ground points
  lpts: [number, number][]; // [[x, y], ...] — logical points
  wkt: string | null;
  pageWidthPt: number;
  pageHeightPt: number;
}

function extractNumbers(arr: PDFArray): number[] {
  const nums: number[] = [];
  for (let i = 0; i < arr.size(); i++) {
    const item = arr.lookup(i);
    if (item instanceof PDFNumber) {
      nums.push(item.asNumber());
    }
  }
  return nums;
}

function extractString(obj: unknown): string | null {
  if (obj instanceof PDFString) return obj.decodeText();
  if (obj instanceof PDFHexString) return obj.decodeText();
  if (typeof obj === 'string') return obj;
  return null;
}

/**
 * Parse georef data from a FAA Instrument Approach Procedure PDF.
 *
 * FAA IAP PDFs embed ISO 32000 Geospatial metadata in the page's /VP
 * (Viewport) array. Each viewport contains:
 *   - /BBox: page-space bounding rectangle
 *   - /Measure → /GPTS: ground points (lat/lng pairs)
 *   - /Measure → /LPTS: logical page points (normalized coords)
 *   - /Measure → /GCS → /WKT: projection string
 */
export async function parseGeoref(
  pdfBytes: Uint8Array,
): Promise<GeorefData | null> {
  const doc = await PDFDocument.load(pdfBytes, { ignoreEncryption: true });
  const pages = doc.getPages();
  if (pages.length === 0) return null;

  const page = pages[0];
  const pageDict = page.node;
  const { width, height } = page.getSize();

  // Access the /VP (Viewport) array from the page dictionary
  const vpArray = pageDict.lookup(PDFName.of('VP'));
  if (!(vpArray instanceof PDFArray)) return null;

  // Iterate viewports — use the first one that has valid georef data
  for (let i = 0; i < vpArray.size(); i++) {
    const viewport = vpArray.lookup(i);
    if (!(viewport instanceof PDFDict)) continue;

    // Extract /BBox
    const bboxArray = viewport.lookup(PDFName.of('BBox'));
    if (!(bboxArray instanceof PDFArray)) continue;
    const bboxNums = extractNumbers(bboxArray);
    if (bboxNums.length < 4) continue;

    // Extract /Measure dictionary
    const measure = viewport.lookup(PDFName.of('Measure'));
    if (!(measure instanceof PDFDict)) continue;

    // Extract /GPTS (Ground Points) — array of lat/lng numbers
    const gptsArray = measure.lookup(PDFName.of('GPTS'));
    if (!(gptsArray instanceof PDFArray)) continue;
    const gptsNums = extractNumbers(gptsArray);
    if (gptsNums.length < 8) continue;

    // Extract /LPTS (Logical Points) — array of normalized x/y numbers
    const lptsArray = measure.lookup(PDFName.of('LPTS'));
    if (!(lptsArray instanceof PDFArray)) continue;
    const lptsNums = extractNumbers(lptsArray);
    if (lptsNums.length < 8) continue;

    // Build paired arrays
    const gpts: [number, number][] = [];
    for (let j = 0; j < gptsNums.length; j += 2) {
      gpts.push([gptsNums[j], gptsNums[j + 1]]);
    }

    const lpts: [number, number][] = [];
    for (let j = 0; j < lptsNums.length; j += 2) {
      lpts.push([lptsNums[j], lptsNums[j + 1]]);
    }

    // Extract WKT from /GCS (Geographic Coordinate System)
    let wkt: string | null = null;
    const gcs = measure.lookup(PDFName.of('GCS'));
    if (gcs instanceof PDFDict) {
      const wktObj = gcs.lookup(PDFName.of('WKT'));
      wkt = extractString(wktObj);
    }

    return {
      bbox: [bboxNums[0], bboxNums[1], bboxNums[2], bboxNums[3]],
      gpts,
      lpts,
      wkt,
      pageWidthPt: width,
      pageHeightPt: height,
    };
  }

  return null;
}
