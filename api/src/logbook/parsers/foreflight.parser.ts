import { CreateLogbookEntryDto } from '../dto/create-logbook-entry.dto';

export interface ParseResult {
  entries: CreateLogbookEntryDto[];
  aircraft: { identifier: string; type: string }[];
  warnings: string[];
  errors: string[];
}

export function parseForeFlight(content: string): ParseResult {
  const lines = content.split('\n').map((l) => l.replace(/\r$/, ''));
  const entries: CreateLogbookEntryDto[] = [];
  const aircraftMap = new Map<string, string>();
  const warnings: string[] = [];
  const errors: string[] = [];

  // Find "Flights Table" section
  let flightsStart = -1;
  let aircraftStart = -1;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (line === 'Flights Table') {
      flightsStart = i;
    }
    if (line === 'Aircraft Table') {
      aircraftStart = i;
    }
  }

  // Parse Aircraft Table first (if present)
  if (aircraftStart >= 0) {
    let headerLine = -1;
    for (let i = aircraftStart + 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      // Skip ForeFlight data type declaration rows
      if (line.startsWith('Text') && line.includes(',')) continue;
      if (headerLine < 0) {
        headerLine = i;
        continue;
      }
      // Stop at next section
      if (line === 'Flights Table' || line === 'Flights Table,') break;

      const headers = parseCsvLine(lines[headerLine]);
      const values = parseCsvLine(line);
      if (values.length < 2) continue;

      const row = mapToObject(headers, values);
      const tailNumber = row['AircraftID'] || row['Tail Number'] || '';
      const type =
        row['TypeCode'] ||
        row['Aircraft Type'] ||
        row['Make and Model'] ||
        '';

      if (tailNumber) {
        aircraftMap.set(tailNumber, type);
      }
    }
  }

  // Parse Flights Table
  if (flightsStart < 0) {
    // No section markers — treat entire file as flights
    flightsStart = -1;
    // Find first non-empty line as header
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].trim() && lines[i].includes('Date')) {
        flightsStart = i - 1;
        break;
      }
    }
    if (flightsStart < 0) {
      errors.push('Could not find flights data in ForeFlight CSV');
      return { entries, aircraft: [], warnings, errors };
    }
  }

  let headerLine = -1;
  for (let i = flightsStart + 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;
    // Skip data type declaration rows
    if (
      line.startsWith('Text') &&
      line.includes(',') &&
      !line.includes('/')
    ) {
      continue;
    }
    if (headerLine < 0) {
      headerLine = i;
      continue;
    }

    const headers = parseCsvLine(lines[headerLine]);
    const values = parseCsvLine(line);
    if (values.length < 3) continue;

    try {
      const row = mapToObject(headers, values);
      const entry = mapForeFlightEntry(row);
      entries.push(entry);

      // Collect aircraft info
      const tail = entry.aircraft_identifier;
      if (tail && !aircraftMap.has(tail)) {
        aircraftMap.set(tail, entry.aircraft_type || '');
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

function mapForeFlightEntry(
  row: Record<string, string>,
): CreateLogbookEntryDto {
  const dto: CreateLogbookEntryDto = {};

  // Date
  const dateStr = row['Date'] || '';
  if (dateStr) {
    dto.date = normalizeDate(dateStr);
  }

  // Aircraft
  dto.aircraft_identifier = row['AircraftID'] || row['Tail Number'] || undefined;
  dto.aircraft_type =
    row['TypeCode'] || row['Aircraft Type'] || row['Make and Model'] || undefined;

  // Route
  const from = normalizeAirportId(row['From'] || '');
  const to = normalizeAirportId(row['To'] || '');
  dto.from_airport = from || undefined;
  dto.to_airport = to || undefined;
  dto.route = row['Route'] || undefined;

  // Times
  dto.total_time = parseFloat2(row['TotalTime'] || row['Total Time']);
  dto.pic = parseFloat2(row['PIC']);
  dto.sic = parseFloat2(row['SIC']);
  dto.night = parseFloat2(row['Night']);
  dto.solo = parseFloat2(row['Solo']);
  dto.cross_country = parseFloat2(
    row['CrossCountry'] || row['Cross Country'],
  );
  dto.actual_instrument = parseFloat2(
    row['ActualInstrument'] || row['Actual Instrument'],
  );
  dto.simulated_instrument = parseFloat2(
    row['SimulatedInstrument'] || row['Simulated Instrument'],
  );
  dto.dual_given = parseFloat2(row['DualGiven'] || row['Dual Given']);
  dto.dual_received = parseFloat2(
    row['DualReceived'] || row['Dual Received'],
  );
  dto.simulated_flight = parseFloat2(
    row['SimulatedFlight'] || row['Simulated Flight'],
  );
  dto.ground_training = parseFloat2(
    row['GroundTraining'] || row['Ground Training'],
  );

  // Hobbs/Tach
  dto.hobbs_start = parseFloat2(row['HobbsStart'] || row['Hobbs Start']);
  dto.hobbs_end = parseFloat2(row['HobbsEnd'] || row['Hobbs End']);
  dto.tach_start = parseFloat2(row['TachStart'] || row['Tach Start']);
  dto.tach_end = parseFloat2(row['TachEnd'] || row['Tach End']);

  // Takeoffs & Landings
  dto.day_takeoffs = parseInt2(row['DayTakeoffs'] || row['Day Takeoffs']);
  dto.night_takeoffs = parseInt2(
    row['NightTakeoffs'] || row['Night Takeoffs'],
  );
  dto.day_landings_full_stop = parseInt2(
    row['DayLandingsFullStop'] ||
      row['Day Landings'] ||
      row['DayLandings'],
  );
  dto.night_landings_full_stop = parseInt2(
    row['NightLandingsFullStop'] ||
      row['Night Landings'] ||
      row['NightLandings'],
  );
  dto.all_landings = parseInt2(
    row['AllLandings'] || row['All Landings'] || row['Landings'],
  );

  // Instrument
  dto.holds = parseInt2(row['Holds'] || row['Hold']);

  // Approaches — ForeFlight packs into Approach1-6 with semicolons
  const approaches: string[] = [];
  for (let i = 1; i <= 6; i++) {
    const appField = row[`Approach${i}`] || '';
    if (appField.trim()) {
      approaches.push(appField.trim());
    }
  }
  // Also check combined "Approaches" field
  const combinedApproaches = row['Approaches'] || '';
  if (combinedApproaches.trim()) {
    approaches.push(
      ...combinedApproaches.split(';').filter((s) => s.trim()),
    );
  }
  if (approaches.length > 0) {
    dto.approaches = approaches.join('; ');
  }

  // People
  dto.instructor_name =
    row['InstructorName'] || row['Instructor Name'] || undefined;
  dto.instructor_comments =
    row['InstructorComments'] || row['Instructor Comments'] || undefined;
  dto.person1 = row['Person1'] || undefined;
  dto.person2 = row['Person2'] || undefined;
  dto.person3 = row['Person3'] || undefined;
  dto.person4 = row['Person4'] || undefined;
  dto.person5 = row['Person5'] || undefined;
  dto.person6 = row['Person6'] || undefined;

  // Flags
  dto.flight_review =
    (row['FlightReview'] || row['Flight Review'] || '') === 'TRUE' ||
    (row['FlightReview'] || row['Flight Review'] || '') === '1';
  dto.checkride = (row['Checkride'] || '') === 'TRUE' || (row['Checkride'] || '') === '1';
  dto.ipc = (row['IPC'] || '') === 'TRUE' || (row['IPC'] || '') === '1';

  // Comments
  dto.comments =
    row['PilotComments'] || row['Comments'] || row['Remarks'] || undefined;

  // Out/Off/On/In times
  dto.time_out = row['TimeOut'] || row['Out'] || undefined;
  dto.time_off = row['TimeOff'] || row['Off'] || undefined;
  dto.time_on = row['TimeOn'] || row['On'] || undefined;
  dto.time_in = row['TimeIn'] || row['In'] || undefined;

  return dto;
}

function normalizeAirportId(id: string): string {
  const trimmed = id.trim().toUpperCase();
  // Strip leading K for US airports (KAPA -> APA)
  if (trimmed.length === 4 && trimmed.startsWith('K')) {
    return trimmed.slice(1);
  }
  return trimmed;
}

function normalizeDate(dateStr: string): string {
  // ForeFlight uses YYYY-MM-DD or MM/DD/YYYY
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
