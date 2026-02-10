import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { LogbookEntry } from './entities/logbook-entry.entity';
import { CreateLogbookEntryDto } from './dto/create-logbook-entry.dto';
import { UpdateLogbookEntryDto } from './dto/update-logbook-entry.dto';

@Injectable()
export class LogbookService {
  constructor(
    @InjectRepository(LogbookEntry)
    private readonly entryRepo: Repository<LogbookEntry>,
  ) {}

  async findAll(
    userId: string,
    query?: string,
    limit = 50,
    offset = 0,
  ): Promise<{
    items: LogbookEntry[];
    total: number;
    limit: number;
    offset: number;
  }> {
    const qb = this.entryRepo.createQueryBuilder('entry');

    if (query) {
      const q = `%${query}%`;
      qb.where(
        '(entry.from_airport LIKE :q OR entry.to_airport LIKE :q OR entry.aircraft_identifier LIKE :q OR entry.route LIKE :q OR entry.date LIKE :q OR entry.comments LIKE :q)',
        { q },
      );
    }

    qb.andWhere('(entry.user_id = :userId OR entry.user_id IS NULL)', {
      userId,
    });

    qb.orderBy('entry.date', 'DESC')
      .addOrderBy('entry.id', 'DESC')
      .skip(offset)
      .take(limit);

    const [items, total] = await qb.getManyAndCount();
    return { items, total, limit, offset };
  }

  async getSummary(userId: string): Promise<{
    totalEntries: number;
    totalTime: number;
    last7Days: number;
    last30Days: number;
    last90Days: number;
    last6Months: number;
    last12Months: number;
  }> {
    const allEntries = await this.entryRepo.find({
      where: [{ user_id: userId }, { user_id: IsNull() }],
    });
    const now = new Date();

    const totalEntries = allEntries.length;
    const totalTime = allEntries.reduce(
      (sum, e) => sum + (e.total_time || 0),
      0,
    );

    const timeInPeriod = (days: number) => {
      const cutoff = new Date(now);
      cutoff.setDate(cutoff.getDate() - days);
      const cutoffStr = cutoff.toISOString().slice(0, 10);
      return allEntries
        .filter((e) => e.date && e.date >= cutoffStr)
        .reduce((sum, e) => sum + (e.total_time || 0), 0);
    };

    return {
      totalEntries,
      totalTime: Math.round(totalTime * 10) / 10,
      last7Days: Math.round(timeInPeriod(7) * 10) / 10,
      last30Days: Math.round(timeInPeriod(30) * 10) / 10,
      last90Days: Math.round(timeInPeriod(90) * 10) / 10,
      last6Months: Math.round(timeInPeriod(183) * 10) / 10,
      last12Months: Math.round(timeInPeriod(365) * 10) / 10,
    };
  }

  async getExperienceReport(
    userId: string,
    period?: string,
  ): Promise<{
    rows: Record<string, any>[];
    totals: Record<string, any>;
  }> {
    const allEntries = await this.entryRepo.find({
      where: [{ user_id: userId }, { user_id: IsNull() }],
    });
    const now = new Date();

    // Filter by period if specified
    let entries = allEntries;
    if (period && period !== 'all') {
      const periodDays: Record<string, number> = {
        '7d': 7,
        '30d': 30,
        '90d': 90,
        '6mo': 183,
        '12mo': 365,
      };
      const days = periodDays[period];
      if (days) {
        const cutoff = new Date(now);
        cutoff.setDate(cutoff.getDate() - days);
        const cutoffStr = cutoff.toISOString().slice(0, 10);
        entries = entries.filter((e) => e.date && e.date >= cutoffStr);
      }
    }

    // Group by aircraft_type
    const groups = new Map<string, LogbookEntry[]>();
    for (const entry of entries) {
      const type = entry.aircraft_type || 'Unknown';
      if (!groups.has(type)) groups.set(type, []);
      groups.get(type)!.push(entry);
    }

    const round1 = (n: number) => Math.round(n * 10) / 10;

    const sumGroup = (groupEntries: LogbookEntry[], aircraftType: string) => ({
      aircraftType,
      flightCount: groupEntries.length,
      totalTime: round1(
        groupEntries.reduce((s, e) => s + (e.total_time || 0), 0),
      ),
      dayLandings: groupEntries.reduce(
        (s, e) => s + (e.day_landings_full_stop || 0),
        0,
      ),
      nightLandings: groupEntries.reduce(
        (s, e) => s + (e.night_landings_full_stop || 0),
        0,
      ),
      allLandings: groupEntries.reduce((s, e) => s + (e.all_landings || 0), 0),
      pic: round1(groupEntries.reduce((s, e) => s + (e.pic || 0), 0)),
      sic: round1(groupEntries.reduce((s, e) => s + (e.sic || 0), 0)),
      crossCountry: round1(
        groupEntries.reduce((s, e) => s + (e.cross_country || 0), 0),
      ),
      actualInstrument: round1(
        groupEntries.reduce((s, e) => s + (e.actual_instrument || 0), 0),
      ),
      simulatedInstrument: round1(
        groupEntries.reduce((s, e) => s + (e.simulated_instrument || 0), 0),
      ),
      night: round1(groupEntries.reduce((s, e) => s + (e.night || 0), 0)),
      solo: round1(groupEntries.reduce((s, e) => s + (e.solo || 0), 0)),
      dualGiven: round1(
        groupEntries.reduce((s, e) => s + (e.dual_given || 0), 0),
      ),
      dualReceived: round1(
        groupEntries.reduce((s, e) => s + (e.dual_received || 0), 0),
      ),
      holds: groupEntries.reduce((s, e) => s + (e.holds || 0), 0),
      dayTakeoffs: groupEntries.reduce((s, e) => s + (e.day_takeoffs || 0), 0),
      nightTakeoffs: groupEntries.reduce(
        (s, e) => s + (e.night_takeoffs || 0),
        0,
      ),
    });

    const rows = Array.from(groups.entries())
      .map(([type, groupEntries]) => sumGroup(groupEntries, type))
      .sort((a, b) => b.totalTime - a.totalTime);

    const totals = sumGroup(entries, 'Totals');

    return { rows, totals };
  }

  async findOne(userId: string, id: number): Promise<LogbookEntry> {
    const entry = await this.entryRepo.findOne({
      where: [
        { id, user_id: userId },
        { id, user_id: IsNull() },
      ],
    });
    if (!entry) {
      throw new NotFoundException(`Logbook entry #${id} not found`);
    }
    return entry;
  }

  async create(
    userId: string,
    dto: CreateLogbookEntryDto,
  ): Promise<LogbookEntry> {
    const entry = this.entryRepo.create({ ...dto, user_id: userId });
    return this.entryRepo.save(entry);
  }

  async update(
    userId: string,
    id: number,
    dto: UpdateLogbookEntryDto,
  ): Promise<LogbookEntry> {
    const entry = await this.findOne(userId, id);
    Object.assign(entry, dto);
    return this.entryRepo.save(entry);
  }

  async remove(userId: string, id: number): Promise<void> {
    const entry = await this.findOne(userId, id);
    await this.entryRepo.remove(entry);
  }
}
