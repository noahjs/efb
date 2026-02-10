import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { LogbookEntry } from './entities/logbook-entry.entity';
import { CreateLogbookEntryDto } from './dto/create-logbook-entry.dto';
import { parseForeFlight, ParseResult } from './parsers/foreflight.parser';
import { parseGarmin } from './parsers/garmin.parser';

export interface ImportResult {
  entries: CreateLogbookEntryDto[];
  aircraft: { identifier: string; type: string }[];
  warnings: string[];
  errors: string[];
  duplicates: number[];
  totalEntries: number;
  totalTime: number;
  importedCount?: number;
}

@Injectable()
export class ImportService {
  constructor(
    @InjectRepository(LogbookEntry)
    private readonly entryRepo: Repository<LogbookEntry>,
  ) {}

  async processImport(
    fileContent: string,
    source: string,
    preview: boolean,
  ): Promise<ImportResult> {
    // Parse based on source
    let parsed: ParseResult;
    if (source === 'foreflight') {
      parsed = parseForeFlight(fileContent);
    } else if (source === 'garmin') {
      parsed = parseGarmin(fileContent);
    } else {
      throw new BadRequestException(`Unknown source: ${source}`);
    }

    if (parsed.entries.length === 0) {
      return {
        entries: parsed.entries,
        aircraft: parsed.aircraft,
        warnings: parsed.warnings,
        errors: parsed.errors,
        duplicates: [],
        totalEntries: 0,
        totalTime: 0,
      };
    }

    // Calculate totals
    const totalTime = parsed.entries.reduce(
      (sum, e) => sum + (e.total_time || 0),
      0,
    );

    // Detect duplicates by matching on (date, aircraft_identifier, from_airport, to_airport, total_time)
    const dates = parsed.entries
      .map((e) => e.date)
      .filter((d): d is string => !!d);
    const minDate = dates.length > 0 ? dates.sort()[0] : null;
    const maxDate = dates.length > 0 ? dates.sort()[dates.length - 1] : null;

    let existingEntries: LogbookEntry[] = [];
    if (minDate && maxDate) {
      existingEntries = await this.entryRepo
        .createQueryBuilder('e')
        .where('e.date >= :minDate AND e.date <= :maxDate', {
          minDate,
          maxDate,
        })
        .getMany();
    }

    // Build a set of existing entry signatures for fast lookup
    const existingSet = new Set<string>();
    for (const e of existingEntries) {
      const sig = this.entrySignature(
        e.date,
        e.aircraft_identifier,
        e.from_airport,
        e.to_airport,
        e.total_time,
      );
      existingSet.add(sig);
    }

    // Mark which parsed entries are duplicates
    const duplicateIndices: number[] = [];
    for (let i = 0; i < parsed.entries.length; i++) {
      const e = parsed.entries[i];
      const sig = this.entrySignature(
        e.date,
        e.aircraft_identifier,
        e.from_airport,
        e.to_airport,
        e.total_time,
      );
      if (existingSet.has(sig)) {
        duplicateIndices.push(i);
      }
    }

    if (preview) {
      return {
        entries: parsed.entries,
        aircraft: parsed.aircraft,
        warnings: parsed.warnings,
        errors: parsed.errors,
        duplicates: duplicateIndices,
        totalEntries: parsed.entries.length,
        totalTime: Math.round(totalTime * 10) / 10,
      };
    }

    // Import mode: save non-duplicate entries
    const duplicateSet = new Set(duplicateIndices);
    const toImport = parsed.entries.filter((_, i) => !duplicateSet.has(i));

    if (toImport.length > 0) {
      const entities = toImport.map((dto) => this.entryRepo.create(dto));
      await this.entryRepo.save(entities);
    }

    return {
      entries: parsed.entries,
      aircraft: parsed.aircraft,
      warnings: parsed.warnings,
      errors: parsed.errors,
      duplicates: duplicateIndices,
      totalEntries: parsed.entries.length,
      totalTime: Math.round(totalTime * 10) / 10,
      importedCount: toImport.length,
    };
  }

  private entrySignature(
    date?: string,
    aircraftIdentifier?: string,
    fromAirport?: string,
    toAirport?: string,
    totalTime?: number,
  ): string {
    return [
      date || '',
      (aircraftIdentifier || '').toUpperCase(),
      (fromAirport || '').toUpperCase(),
      (toAirport || '').toUpperCase(),
      totalTime != null ? totalTime.toFixed(1) : '',
    ].join('|');
  }
}
