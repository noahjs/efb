import { CreateLogbookEntryDto } from '../dto/create-logbook-entry.dto';

export interface ParseResult {
  entries: CreateLogbookEntryDto[];
  aircraft: { identifier: string; type: string }[];
  warnings: string[];
  errors: string[];
}

export function parseGarmin(content: string): ParseResult {
  const lines = content.split('\n').map((l) => l.replace(/\r$/, ''));
  const entries: CreateLogbookEntryDto[] = [];
  const aircraftMap = new Map<string, string>();
  const warnings: string[] = [];
  const errors: string[] = [];

  // Find header line (first line with "Date" column)
  let headerLine = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].toLowerCase().includes('date')) {
      headerLine = i;
      break;
    }
  }

  if (headerLine < 0) {
    errors.push('Could not find header row in Garmin CSV');
    return { entries, aircraft: [], warnings, errors };
  }

  const headers = parseCsvLine(lines[headerLine]);

  for (let i = headerLine + 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    const values = parseCsvLine(line);
    if (values.length < 3) continue;

    try {
      const row = mapToObject(headers, values);
      const entry = mapGarminEntry(row);
      entries.push(entry);

      // Collect aircraft info
      const tail = entry.aircraft_identifier;
      const type = entry.aircraft_type || '';
      if (tail && !aircraftMap.has(tail)) {
        aircraftMap.set(tail, type);
      }
    } catch (e) {
      errors.push(`Row ${i + 1}: ${e.message || e}`);
    }
  }

  const aircraft = Array.from(aircraftMap.entries()).map(
    ([identifier, type]) => ({ identifier, type }),
  );

  return { entries, aircraft, warnings, errors };
}

function mapGarminEntry(
  row: Record<string, string>,
): CreateLogbookEntryDto {
  const dto: CreateLogbookEntryDto = {};

  // Date — Garmin uses M/D/YYYY
  const dateStr = row['Date'] || '';
  if (dateStr) {
    dto.date = normalizeDate(dateStr);
  }

  // Aircraft
  dto.aircraft_identifier =
    row['Aircraft ID'] || row['AircraftID'] || row['Tail Number'] || undefined;
  dto.aircraft_type =
    row['Aircraft Type'] || row['Type'] || row['Model'] || undefined;

  // Route — Garmin uses FAA 3-letter identifiers (no normalization needed)
  dto.from_airport = (row['From'] || row['Departure'] || '').trim() || undefined;
  dto.to_airport = (row['To'] || row['Arrival'] || row['Destination'] || '').trim() || undefined;
  dto.route = row['Route'] || undefined;

  // Times
  dto.total_time = parseFloat2(row['Total Time'] || row['TotalTime'] || row['Total Duration']);
  dto.pic = parseFloat2(row['PIC']);
  dto.sic = parseFloat2(row['SIC']);
  dto.night = parseFloat2(row['Night']);
  dto.solo = parseFloat2(row['Solo']);
  dto.cross_country = parseFloat2(row['Cross Country'] || row['XC']);
  dto.actual_instrument = parseFloat2(
    row['Actual Instrument'] || row['Actual Inst'] || row['Act Inst'],
  );
  dto.simulated_instrument = parseFloat2(
    row['Simulated Instrument'] || row['Sim Inst'] || row['Hood'],
  );
  dto.dual_given = parseFloat2(row['Dual Given'] || row['CFI']);
  dto.dual_received = parseFloat2(
    row['Dual Received'] || row['Dual Rcvd'],
  );
  dto.ground_training = parseFloat2(row['Ground Training'] || row['Ground']);

  // Takeoffs & Landings
  dto.day_takeoffs = parseInt2(row['Day Takeoffs'] || row['Day T/O']);
  dto.night_takeoffs = parseInt2(
    row['Night Takeoffs'] || row['Night T/O'],
  );
  dto.day_landings_full_stop = parseInt2(
    row['Day Landings'] || row['Day Ldg'] || row['Day Full Stop'],
  );
  dto.night_landings_full_stop = parseInt2(
    row['Night Landings'] || row['Night Ldg'] || row['Night Full Stop'],
  );
  dto.all_landings = parseInt2(row['All Landings'] || row['Landings']);

  // Instrument
  dto.holds = parseInt2(row['Holds'] || row['Hold']);
  const approaches = row['Approaches'] || row['Instrument Approaches'] || '';
  if (approaches.trim()) {
    dto.approaches = approaches.trim();
  }

  // People
  dto.instructor_name = row['Instructor'] || row['Instructor Name'] || undefined;
  dto.comments = row['Comments'] || row['Remarks'] || row['Notes'] || undefined;

  // Flags
  dto.flight_review =
    (row['Flight Review'] || row['BFR'] || '') === 'Yes' ||
    (row['Flight Review'] || row['BFR'] || '') === 'TRUE' ||
    (row['Flight Review'] || row['BFR'] || '') === '1';
  dto.ipc =
    (row['IPC'] || '') === 'Yes' ||
    (row['IPC'] || '') === 'TRUE' ||
    (row['IPC'] || '') === '1';

  return dto;
}

function normalizeDate(dateStr: string): string {
  // Garmin uses M/D/YYYY
  if (dateStr.includes('/')) {
    const parts = dateStr.split('/');
    if (parts.length === 3) {
      const month = parts[0].padStart(2, '0');
      const day = parts[1].padStart(2, '0');
      const year =
        parts[2].length === 2 ? '20' + parts[2] : parts[2];
      return `${year}-${month}-${day}`;
    }
  }
  return dateStr;
}

function parseFloat2(val: string | undefined): number | undefined {
  if (!val || val.trim() === '') return undefined;
  const n = parseFloat(val);
  return isNaN(n) ? undefined : n;
}

function parseInt2(val: string | undefined): number | undefined {
  if (!val || val.trim() === '') return undefined;
  const n = parseInt(val, 10);
  return isNaN(n) ? undefined : n;
}

function parseCsvLine(line: string): string[] {
  const result: string[] = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (inQuotes) {
      if (char === '"') {
        if (i + 1 < line.length && line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current += char;
      }
    } else if (char === '"') {
      inQuotes = true;
    } else if (char === ',') {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

function mapToObject(
  headers: string[],
  values: string[],
): Record<string, string> {
  const obj: Record<string, string> = {};
  for (let i = 0; i < headers.length; i++) {
    obj[headers[i]] = values[i] || '';
  }
  return obj;
}
