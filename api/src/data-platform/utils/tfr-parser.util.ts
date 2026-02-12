/**
 * Parses TFR web text HTML from FAA's getWebText API.
 * Extracted from ImageryService for reuse by the TfrPoller.
 */

export function parseTfrWebText(html: string): Record<string, string> {
  const result: Record<string, string> = {};
  if (!html) return result;

  const stripHtml = (s: string) =>
    s
      .replace(/<[^>]+>/g, '')
      .replace(/&[a-z]+;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

  const rowRegex = /<TR[^>]*>([\s\S]*?)<\/TR>/gi;
  let match: RegExpExecArray | null;

  while ((match = rowRegex.exec(html)) !== null) {
    const row = match[1];
    const cells = [...row.matchAll(/<TD[^>]*>([\s\S]*?)<\/TD>/gi)].map((m) =>
      stripHtml(m[1]),
    );

    if (
      cells.length === 1 ||
      (cells.length >= 1 && cells.filter((c) => c).length === 1)
    ) {
      const text = cells.find((c) => c) ?? '';
      const altMatch = text.match(/^Altitude:\s*(.+)/i);
      if (altMatch) {
        result.altitude = altMatch[1].trim();
        continue;
      }
    }

    if (cells.length < 2) continue;

    const label = cells
      .slice(0, -1)
      .join(' ')
      .replace(/\s+/g, ' ')
      .trim()
      .toLowerCase();
    const value = cells[cells.length - 1];

    if (label.includes('location') && !label.includes('latitude')) {
      result.location = value;
    } else if (label.includes('beginning date')) {
      result.effectiveStart = value;
    } else if (label.includes('ending date')) {
      result.effectiveEnd = value;
    } else if (label.includes('altitude')) {
      result.altitude = value;
    } else if (label.includes('reason')) {
      result.reason = value;
    }
  }

  const textCells = [...html.matchAll(/<TD[^>]*>([\s\S]*?)<\/TD>/gi)]
    .map((m) => stripHtml(m[1]))
    .filter((t) => t.length > 200);
  if (textCells.length > 0) {
    result.notamText = textCells[0];
  }

  return result;
}
