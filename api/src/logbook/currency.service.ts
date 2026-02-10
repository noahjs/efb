import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { LogbookEntry } from './entities/logbook-entry.entity';
import { Certificate } from './entities/certificate.entity';

export interface CurrencyItem {
  name: string;
  rule: string;
  status: 'current' | 'expiring_soon' | 'expired';
  expiration_date: string | null;
  details: string;
  action_required: string | null;
}

@Injectable()
export class CurrencyService {
  constructor(
    @InjectRepository(LogbookEntry)
    private readonly entryRepo: Repository<LogbookEntry>,
    @InjectRepository(Certificate)
    private readonly certRepo: Repository<Certificate>,
  ) {}

  async getCurrency(userId: string): Promise<CurrencyItem[]> {
    const entries = await this.entryRepo.find({
      where: [{ user_id: userId }, { user_id: IsNull() }],
      order: { date: 'DESC' },
    });
    const certificates = await this.certRepo.find({
      where: [{ user_id: userId }, { user_id: IsNull() }],
    });
    const now = new Date();

    const items: CurrencyItem[] = [];

    items.push(this.calcDayVfrPassenger(entries, now));
    items.push(this.calcNightVfrPassenger(entries, now));
    items.push(this.calcIfrCurrency(entries, now));
    items.push(this.calcFlightReview(entries, now));
    items.push(this.calcMedical(certificates, now));

    return items;
  }

  // 61.57(a) — 3 takeoffs + 3 landings in preceding 90 days
  private calcDayVfrPassenger(
    entries: LogbookEntry[],
    now: Date,
  ): CurrencyItem {
    const cutoff90 = new Date(now);
    cutoff90.setDate(cutoff90.getDate() - 90);
    const cutoffStr = cutoff90.toISOString().slice(0, 10);

    // Collect qualifying entries (any with day takeoffs or day landings)
    const qualifying = entries.filter(
      (e) =>
        e.date &&
        e.date >= cutoffStr &&
        ((e.day_takeoffs || 0) > 0 ||
          (e.day_landings_full_stop || 0) > 0 ||
          (e.all_landings || 0) > 0),
    );

    // Sum totals
    let totalTakeoffs = 0;
    let totalLandings = 0;
    for (const e of qualifying) {
      totalTakeoffs += e.day_takeoffs || 0;
      totalLandings +=
        (e.day_landings_full_stop || 0) > 0
          ? e.day_landings_full_stop
          : e.all_landings || 0;
    }

    // Find expiration: date of the entry that satisfies the 3rd takeoff/landing + 90 days
    let expirationDate: string | null = null;
    let status: CurrencyItem['status'] = 'expired';

    if (totalTakeoffs >= 3 && totalLandings >= 3) {
      // Walk entries chronologically to find the 3rd qualifying event
      const sorted = [...qualifying].sort((a, b) =>
        (a.date || '').localeCompare(b.date || ''),
      );
      let cumTakeoffs = 0;
      let cumLandings = 0;
      let thirdDate: string | null = null;

      for (const e of sorted) {
        cumTakeoffs += e.day_takeoffs || 0;
        cumLandings +=
          (e.day_landings_full_stop || 0) > 0
            ? e.day_landings_full_stop
            : e.all_landings || 0;
        if (cumTakeoffs >= 3 && cumLandings >= 3) {
          thirdDate = e.date;
          break;
        }
      }

      if (thirdDate) {
        const exp = new Date(thirdDate);
        exp.setDate(exp.getDate() + 90);
        expirationDate = exp.toISOString().slice(0, 10);

        const daysUntil = Math.floor(
          (exp.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
        );
        if (daysUntil < 0) {
          status = 'expired';
        } else if (daysUntil <= 30) {
          status = 'expiring_soon';
        } else {
          status = 'current';
        }
      }
    }

    return {
      name: 'Day VFR Passenger',
      rule: '14 CFR 61.57(a)',
      status,
      expiration_date: expirationDate,
      details: `${totalTakeoffs} takeoffs, ${totalLandings} landings in last 90 days (need 3 each)`,
      action_required:
        status === 'expired'
          ? 'Perform 3 takeoffs and 3 landings to carry passengers'
          : null,
    };
  }

  // 61.57(b) — 3 night full-stop landings in preceding 90 days
  private calcNightVfrPassenger(
    entries: LogbookEntry[],
    now: Date,
  ): CurrencyItem {
    const cutoff90 = new Date(now);
    cutoff90.setDate(cutoff90.getDate() - 90);
    const cutoffStr = cutoff90.toISOString().slice(0, 10);

    const qualifying = entries.filter(
      (e) =>
        e.date && e.date >= cutoffStr && (e.night_landings_full_stop || 0) > 0,
    );

    let totalNightLandings = 0;
    for (const e of qualifying) {
      totalNightLandings += e.night_landings_full_stop || 0;
    }

    let expirationDate: string | null = null;
    let status: CurrencyItem['status'] = 'expired';

    if (totalNightLandings >= 3) {
      const sorted = [...qualifying].sort((a, b) =>
        (a.date || '').localeCompare(b.date || ''),
      );
      let cumLandings = 0;
      let thirdDate: string | null = null;

      for (const e of sorted) {
        cumLandings += e.night_landings_full_stop || 0;
        if (cumLandings >= 3) {
          thirdDate = e.date;
          break;
        }
      }

      if (thirdDate) {
        const exp = new Date(thirdDate);
        exp.setDate(exp.getDate() + 90);
        expirationDate = exp.toISOString().slice(0, 10);

        const daysUntil = Math.floor(
          (exp.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
        );
        if (daysUntil < 0) {
          status = 'expired';
        } else if (daysUntil <= 30) {
          status = 'expiring_soon';
        } else {
          status = 'current';
        }
      }
    }

    return {
      name: 'Night VFR Passenger',
      rule: '14 CFR 61.57(b)',
      status,
      expiration_date: expirationDate,
      details: `${totalNightLandings} night full-stop landings in last 90 days (need 3)`,
      action_required:
        status === 'expired'
          ? 'Perform 3 night full-stop landings to carry passengers at night'
          : null,
    };
  }

  // 61.57(c) — 6 approaches + holding in 6 calendar months
  private calcIfrCurrency(entries: LogbookEntry[], now: Date): CurrencyItem {
    // 6 calendar months back (end of that month)
    const sixMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 6, 1);
    const sixMonthCutoff = sixMonthsAgo.toISOString().slice(0, 10);

    // 12 calendar months for grace period
    const twelveMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 12, 1);
    const twelveMonthCutoff = twelveMonthsAgo.toISOString().slice(0, 10);

    // Count approaches and holds in 6-month window
    const inSixMonths = entries.filter(
      (e) => e.date && e.date >= sixMonthCutoff,
    );
    let approachCount6 = 0;
    let hasHolds6 = false;

    for (const e of inSixMonths) {
      approachCount6 += this.countApproaches(e);
      if ((e.holds || 0) > 0) hasHolds6 = true;
    }

    // Check if IPC was done
    const hasIpc = entries.some(
      (e) => e.date && e.date >= twelveMonthCutoff && e.ipc,
    );

    // Count in 12-month window for grace period
    const inTwelveMonths = entries.filter(
      (e) => e.date && e.date >= twelveMonthCutoff,
    );
    let approachCount12 = 0;
    let hasHolds12 = false;

    for (const e of inTwelveMonths) {
      approachCount12 += this.countApproaches(e);
      if ((e.holds || 0) > 0) hasHolds12 = true;
    }

    const current6 = approachCount6 >= 6 && hasHolds6;
    const currentGrace = approachCount12 >= 6 && hasHolds12;

    let status: CurrencyItem['status'] = 'expired';
    let expirationDate: string | null = null;
    let details = '';
    let actionRequired: string | null = null;

    if (current6) {
      // Find when the 6th approach was logged, expiration is end of 6th calendar month
      const mostRecentApproachDate = this.findNthApproachDate(
        entries.filter((e) => e.date && e.date >= sixMonthCutoff),
        6,
      );
      if (mostRecentApproachDate) {
        const expDate = new Date(mostRecentApproachDate);
        expDate.setMonth(expDate.getMonth() + 6);
        // End of that month
        expDate.setMonth(expDate.getMonth() + 1, 0);
        expirationDate = expDate.toISOString().slice(0, 10);

        const daysUntil = Math.floor(
          (expDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
        );
        status = daysUntil <= 30 ? 'expiring_soon' : 'current';
      } else {
        status = 'current';
      }
      details = `${approachCount6} approaches, ${hasHolds6 ? '' : 'no '}holding in last 6 months`;
    } else if (hasIpc) {
      // IPC resets currency
      const ipcEntry = entries.find(
        (e) => e.date && e.date >= twelveMonthCutoff && e.ipc,
      );
      if (ipcEntry?.date) {
        const ipcDate = new Date(ipcEntry.date);
        ipcDate.setMonth(ipcDate.getMonth() + 6);
        ipcDate.setMonth(ipcDate.getMonth() + 1, 0);
        expirationDate = ipcDate.toISOString().slice(0, 10);

        const daysUntil = Math.floor(
          (ipcDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
        );
        if (daysUntil < 0) {
          status = 'expired';
        } else {
          status = daysUntil <= 30 ? 'expiring_soon' : 'current';
        }
      }
      details = `IPC completed, ${approachCount6} approaches in last 6 months`;
    } else if (currentGrace) {
      // In grace period — can regain currency with approaches but cannot fly IFR
      status = 'expiring_soon';
      details = `${approachCount6} approaches in 6 months (grace period — need 6 + holding, or IPC)`;
      actionRequired =
        'Complete 6 approaches + holding with safety pilot, or get an IPC';
    } else {
      status = 'expired';
      details = `${approachCount6} approaches in 6 months (need 6 + holding)`;
      actionRequired = 'Instrument Proficiency Check (IPC) required';
    }

    return {
      name: 'IFR Currency',
      rule: '14 CFR 61.57(c)',
      status,
      expiration_date: expirationDate,
      details,
      action_required: actionRequired,
    };
  }

  // 61.56 — Flight review within 24 calendar months
  private calcFlightReview(entries: LogbookEntry[], now: Date): CurrencyItem {
    // Find most recent flight_review or checkride entry
    const reviewEntry = entries.find(
      (e) => e.date && (e.flight_review || e.checkride),
    );

    if (!reviewEntry?.date) {
      return {
        name: 'Flight Review',
        rule: '14 CFR 61.56',
        status: 'expired',
        expiration_date: null,
        details: 'No flight review on record',
        action_required: 'Complete a flight review (BFR)',
      };
    }

    // Expiration: end of the 24th calendar month after the review
    const reviewDate = new Date(reviewEntry.date);
    const expDate = new Date(
      reviewDate.getFullYear(),
      reviewDate.getMonth() + 24 + 1,
      0,
    );
    const expirationDate = expDate.toISOString().slice(0, 10);

    const daysUntil = Math.floor(
      (expDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
    );

    let status: CurrencyItem['status'];
    if (daysUntil < 0) {
      status = 'expired';
    } else if (daysUntil <= 60) {
      status = 'expiring_soon';
    } else {
      status = 'current';
    }

    const reviewDateStr = reviewDate.toISOString().slice(0, 10);
    return {
      name: 'Flight Review',
      rule: '14 CFR 61.56',
      status,
      expiration_date: expirationDate,
      details: `Last review: ${reviewDateStr}`,
      action_required:
        status === 'expired' ? 'Complete a flight review (BFR)' : null,
    };
  }

  // Medical certificate expiration
  private calcMedical(certificates: Certificate[], now: Date): CurrencyItem {
    const medicals = certificates.filter(
      (c) => c.certificate_type === 'medical',
    );

    if (medicals.length === 0) {
      return {
        name: 'Medical Certificate',
        rule: '14 CFR 61.23',
        status: 'expired',
        expiration_date: null,
        details: 'No medical certificate on record',
        action_required: 'Obtain a medical certificate or BasicMed',
      };
    }

    // Find the medical with the latest expiration
    let latestMedical: Certificate | null = null;
    let latestExpDate: Date | null = null;

    for (const med of medicals) {
      if (med.expiration_date) {
        const exp = new Date(med.expiration_date);
        if (!latestExpDate || exp > latestExpDate) {
          latestExpDate = exp;
          latestMedical = med;
        }
      }
    }

    if (!latestMedical || !latestExpDate) {
      return {
        name: 'Medical Certificate',
        rule: '14 CFR 61.23',
        status: 'current',
        expiration_date: null,
        details: `${this.formatMedicalClass(latestMedical?.certificate_class)} — no expiration set`,
        action_required: null,
      };
    }

    const expirationDate = latestExpDate.toISOString().slice(0, 10);
    const daysUntil = Math.floor(
      (latestExpDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
    );

    let status: CurrencyItem['status'];
    if (daysUntil < 0) {
      status = 'expired';
    } else if (daysUntil <= 30) {
      status = 'expiring_soon';
    } else {
      status = 'current';
    }

    return {
      name: 'Medical Certificate',
      rule: '14 CFR 61.23',
      status,
      expiration_date: expirationDate,
      details: this.formatMedicalClass(latestMedical.certificate_class),
      action_required:
        status === 'expired' ? 'Renew your medical certificate' : null,
    };
  }

  private countApproaches(entry: LogbookEntry): number {
    if (!entry.approaches) return 0;

    // Try parsing as JSON array
    try {
      const parsed = JSON.parse(entry.approaches);
      if (Array.isArray(parsed)) return parsed.length;
    } catch {
      // Not JSON
    }

    // Try counting semicolons or commas (ForeFlight format)
    const text = entry.approaches.trim();
    if (!text) return 0;

    // Count by semicolons first, then commas, then assume 1
    if (text.includes(';')) {
      return text.split(';').filter((s) => s.trim()).length;
    }
    if (text.includes(',')) {
      return text.split(',').filter((s) => s.trim()).length;
    }

    // If it's just a number
    const num = parseInt(text, 10);
    if (!isNaN(num)) return num;

    // Non-empty text = at least 1 approach
    return 1;
  }

  private findNthApproachDate(
    entries: LogbookEntry[],
    n: number,
  ): string | null {
    // Walk chronologically to find when nth approach was logged
    const sorted = [...entries].sort((a, b) =>
      (a.date || '').localeCompare(b.date || ''),
    );
    let count = 0;
    for (const e of sorted) {
      count += this.countApproaches(e);
      if (count >= n) return e.date;
    }
    return null;
  }

  private formatMedicalClass(cls?: string): string {
    switch (cls) {
      case 'first_class':
        return 'First Class Medical';
      case 'second_class':
        return 'Second Class Medical';
      case 'third_class':
        return 'Third Class Medical';
      case 'basicmed':
        return 'BasicMed';
      default:
        return 'Medical Certificate';
    }
  }
}
