/**
 * ILS DME identification box (upper-right of plan view).
 */
import { GeoProjection, ILSInfo } from './types';

export function renderIlsBox(
  proj: GeoProjection,
  ils: ILSInfo,
  /** top-right corner offset from chart edge */
  offsetX = 10,
  offsetY = 12,
): string {
  const W = proj.size.width;
  const boxW = 135;
  const boxH = 28;
  const bx = W - offsetX - boxW;
  const by = offsetY;

  const lines: string[] = [];
  lines.push(`<g id="plan-ils-box">`);

  // Box outline
  lines.push(
    `  <rect x="${bx}" y="${by}" width="${boxW}" height="${boxH}" fill="#fff" stroke="#000" stroke-width="1.5"/>`,
  );

  // "ILS DME" label above box
  lines.push(
    `  <text x="${bx + 4}" y="${by + 9}" font-size="5.5" font-weight="400">ILS DME</text>`,
  );

  // Localizer course dashes inside box (left and right of text)
  const dashY = by + boxH / 2 + 4;
  lines.push(
    `  <line x1="${bx + 3}" y1="${dashY}" x2="${bx + 18}" y2="${dashY}" stroke="#000" stroke-width="2.5" stroke-dasharray="5,3"/>`,
  );
  lines.push(
    `  <line x1="${bx + boxW - 18}" y1="${dashY}" x2="${bx + boxW - 3}" y2="${dashY}" stroke="#000" stroke-width="2.5" stroke-dasharray="5,3"/>`,
  );

  // Course / Frequency / Ident inside box
  const textY = by + boxH / 2 + 7;
  lines.push(
    `  <text x="${bx + 30}" y="${textY}" font-size="10" font-weight="700">${ils.course}&deg;</text>`,
  );
  lines.push(
    `  <text x="${bx + 60}" y="${textY}" font-size="10" font-weight="700">${ils.freq}</text>`,
  );
  lines.push(
    `  <text x="${bx + 100}" y="${textY}" font-size="10" font-weight="700">${ils.locId}</text>`,
  );

  lines.push(`</g>`);
  return lines.join('\n');
}
