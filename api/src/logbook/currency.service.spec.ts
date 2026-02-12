import { CurrencyService } from './currency.service';
import { LogbookEntry } from './entities/logbook-entry.entity';
import { Certificate } from './entities/certificate.entity';

/**
 * Tests for CurrencyService — FAA regulatory currency calculations.
 * All calc* methods are private but invoked through getCurrency().
 * We test via public API and also access private helpers directly.
 */
describe('CurrencyService', () => {
  let service: CurrencyService;

  /** Build a minimal logbook entry with sensible defaults */
  function entry(overrides: Partial<LogbookEntry>): LogbookEntry {
    return {
      id: Math.floor(Math.random() * 10000),
      date: null as any,
      day_takeoffs: 0,
      day_landings_full_stop: 0,
      all_landings: 0,
      night_takeoffs: 0,
      night_landings_full_stop: 0,
      holds: 0,
      approaches: null as any,
      flight_review: false,
      checkride: false,
      ipc: false,
      total_time: 0,
      pic: 0,
      sic: 0,
      night: 0,
      solo: 0,
      cross_country: 0,
      actual_instrument: 0,
      simulated_instrument: 0,
      dual_given: 0,
      dual_received: 0,
      simulated_flight: 0,
      ground_training: 0,
      autorotations: 0,
      full_down_autorotations: 0,
      hovering_autorotations: 0,
      ...overrides,
    } as LogbookEntry;
  }

  /** ISO date string N days ago from the reference date */
  function daysAgo(n: number, from: Date = new Date('2025-03-15')): string {
    const d = new Date(from);
    d.setDate(d.getDate() - n);
    return d.toISOString().slice(0, 10);
  }

  beforeEach(() => {
    // Private calc methods are synchronous — no repo needed
    service = new CurrencyService(null as any, null as any);
  });

  // ─── countApproaches ───

  describe('countApproaches', () => {
    const count = (approaches: string | null) =>
      (service as any).countApproaches(
        entry({ approaches: approaches as any }),
      );

    it('should parse a plain number', () => {
      expect(count('3')).toBe(3);
    });

    it('should count JSON array elements', () => {
      expect(count('[1,2,3]')).toBe(3);
      expect(count('["ILS 28L","VOR 17","RNAV 35"]')).toBe(3);
    });

    it('should count semicolon-separated approaches', () => {
      expect(count('ILS 28L;ILS 28R;VOR 17')).toBe(3);
    });

    it('should count comma-separated approaches', () => {
      expect(count('ILS 28L, ILS 28R')).toBe(2);
    });

    it('should return 0 for null/empty', () => {
      expect(count(null)).toBe(0);
      expect(count('')).toBe(0);
      expect(count('   ')).toBe(0);
    });

    it('should return 1 for non-numeric non-delimited text', () => {
      expect(count('ILS 28L')).toBe(1);
    });
  });

  // ─── Day VFR Passenger Currency — 14 CFR 61.57(a) ───

  describe('calcDayVfrPassenger', () => {
    const calc = (entries: LogbookEntry[], now: Date) =>
      (service as any).calcDayVfrPassenger(entries, now);

    it('should be current with 3+ takeoffs and 3+ landings in 90 days', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({
          date: daysAgo(10, now),
          day_takeoffs: 2,
          day_landings_full_stop: 2,
        }),
        entry({
          date: daysAgo(30, now),
          day_takeoffs: 1,
          day_landings_full_stop: 1,
        }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
    });

    it('should be expired with fewer than 3 takeoffs/landings', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({
          date: daysAgo(10, now),
          day_takeoffs: 1,
          day_landings_full_stop: 1,
        }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('expired');
    });

    it('should compute expiration date as 3rd qualifying entry + 90 days', () => {
      const now = new Date('2025-03-15');
      // 3 entries on the same day 20 days ago
      const flightDate = daysAgo(20, now);
      const entries = [
        entry({ date: flightDate, day_takeoffs: 3, day_landings_full_stop: 3 }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
      expect(result.expiration_date).not.toBeNull();

      // Expiration should be flight date + 90 days
      const exp = new Date(result.expiration_date);
      const expected = new Date(flightDate);
      expected.setDate(expected.getDate() + 90);
      expect(exp.toISOString().slice(0, 10)).toBe(
        expected.toISOString().slice(0, 10),
      );
    });

    it('should not count entries older than 90 days', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({
          date: daysAgo(91, now),
          day_takeoffs: 5,
          day_landings_full_stop: 5,
        }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('expired');
    });

    it('should use all_landings when day_landings_full_stop is 0', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({
          date: daysAgo(10, now),
          day_takeoffs: 3,
          day_landings_full_stop: 0,
          all_landings: 3,
        }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
    });
  });

  // ─── Night VFR Passenger Currency — 14 CFR 61.57(b) ───

  describe('calcNightVfrPassenger', () => {
    const calc = (entries: LogbookEntry[], now: Date) =>
      (service as any).calcNightVfrPassenger(entries, now);

    it('should be current with 3+ night full-stop landings in 90 days', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({ date: daysAgo(15, now), night_landings_full_stop: 3 }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
    });

    it('should be expired with fewer than 3 night landings', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({ date: daysAgo(15, now), night_landings_full_stop: 2 }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('expired');
    });

    it('should accumulate across multiple entries', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({ date: daysAgo(10, now), night_landings_full_stop: 1 }),
        entry({ date: daysAgo(20, now), night_landings_full_stop: 1 }),
        entry({ date: daysAgo(30, now), night_landings_full_stop: 1 }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
    });
  });

  // ─── IFR Currency — 14 CFR 61.57(c) ───

  describe('calcIfrCurrency', () => {
    const calc = (entries: LogbookEntry[], now: Date) =>
      (service as any).calcIfrCurrency(entries, now);

    it('should be current with 6+ approaches and holding in 6 months', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({
          date: daysAgo(30, now),
          approaches: '6',
          holds: 1,
        }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
    });

    it('should not be current without holding even with 6 approaches', () => {
      const now = new Date('2025-03-15');
      const entries = [
        entry({
          date: daysAgo(30, now),
          approaches: '6',
          holds: 0,
        }),
      ];
      const result = calc(entries, now);
      expect(result.status).toBe('expired');
    });

    it('should be current after IPC even without approaches', () => {
      const now = new Date('2025-03-15');
      const entries = [entry({ date: daysAgo(30, now), ipc: true })];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
    });

    it('should expire when IPC was > 6 months ago (end of calendar month)', () => {
      const now = new Date('2025-03-15');
      // IPC 8 months ago
      const entries = [entry({ date: '2024-07-01', ipc: true })];
      const result = calc(entries, now);
      // IPC on Jul 1 → expires end of Jan 2025 → should be expired by Mar 15
      expect(result.status).toBe('expired');
    });

    it('should be in grace period with 6 approaches in 12 months but not 6', () => {
      const now = new Date('2025-03-15');
      // 4 approaches in last 6 months, 3 more 8 months ago
      const entries = [
        entry({ date: daysAgo(30, now), approaches: '4', holds: 1 }),
        entry({ date: '2024-07-15', approaches: '3', holds: 1 }),
      ];
      const result = calc(entries, now);
      // 7 total in 12 months, only 4 in 6 months → grace period
      expect(result.status).toBe('expiring_soon');
      expect(result.action_required).toContain('IPC');
    });
  });

  // ─── Flight Review — 14 CFR 61.56 ───

  describe('calcFlightReview', () => {
    const calc = (entries: LogbookEntry[], now: Date) =>
      (service as any).calcFlightReview(entries, now);

    it('should be current when flight review is within 24 calendar months', () => {
      const now = new Date('2025-03-15');
      const entries = [entry({ date: '2024-06-15', flight_review: true })];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
      // Should expire end of June 2026
      expect(result.expiration_date).toBe('2026-06-30');
    });

    it('should be expired when flight review is > 24 calendar months ago', () => {
      const now = new Date('2025-03-15');
      const entries = [entry({ date: '2022-12-01', flight_review: true })];
      const result = calc(entries, now);
      // Dec 2022 + 24 months = end of Dec 2024 → expired
      expect(result.status).toBe('expired');
    });

    it('should treat checkride as flight review', () => {
      const now = new Date('2025-03-15');
      const entries = [entry({ date: '2024-06-15', checkride: true })];
      const result = calc(entries, now);
      expect(result.status).toBe('current');
    });

    it('should return expired when no review on record', () => {
      const now = new Date('2025-03-15');
      const result = calc([], now);
      expect(result.status).toBe('expired');
      expect(result.expiration_date).toBeNull();
    });

    it('should show expiring_soon when within 60 days of expiration', () => {
      const now = new Date('2025-03-15');
      // Review on April 1, 2023 → expires end of April 2025 (46 days away)
      const entries = [entry({ date: '2023-04-01', flight_review: true })];
      const result = calc(entries, now);
      expect(result.status).toBe('expiring_soon');
    });
  });

  // ─── Medical Certificate — 14 CFR 61.23 ───

  describe('calcMedical', () => {
    const calc = (certs: Certificate[], now: Date) =>
      (service as any).calcMedical(certs, now);

    function cert(overrides: Partial<Certificate>): Certificate {
      return {
        id: 1,
        certificate_type: 'medical',
        certificate_class: 'third_class',
        certificate_number: null as any,
        issue_date: null as any,
        expiration_date: null as any,
        ratings: null as any,
        limitations: null as any,
        comments: null as any,
        ...overrides,
      } as Certificate;
    }

    it('should be current when medical has not expired', () => {
      const now = new Date('2025-03-15');
      const certs = [cert({ expiration_date: '2026-03-31' })];
      const result = calc(certs, now);
      expect(result.status).toBe('current');
    });

    it('should be expired when medical has passed expiration', () => {
      const now = new Date('2025-03-15');
      const certs = [cert({ expiration_date: '2024-12-31' })];
      const result = calc(certs, now);
      expect(result.status).toBe('expired');
    });

    it('should be expiring_soon when within 30 days of expiration', () => {
      const now = new Date('2025-03-15');
      const certs = [cert({ expiration_date: '2025-04-01' })];
      const result = calc(certs, now);
      expect(result.status).toBe('expiring_soon');
    });

    it('should use the latest expiration when multiple medicals exist', () => {
      const now = new Date('2025-03-15');
      const certs = [
        cert({
          expiration_date: '2024-12-31',
          certificate_class: 'third_class',
        }),
        cert({
          expiration_date: '2026-06-30',
          certificate_class: 'first_class',
        }),
      ];
      const result = calc(certs, now);
      expect(result.status).toBe('current');
      expect(result.expiration_date).toBe('2026-06-30');
    });

    it('should return expired when no medicals on record', () => {
      const now = new Date('2025-03-15');
      const result = calc([], now);
      expect(result.status).toBe('expired');
      expect(result.expiration_date).toBeNull();
    });

    it('should format medical class names', () => {
      const now = new Date('2025-03-15');
      const certs = [
        cert({
          expiration_date: '2026-06-30',
          certificate_class: 'first_class',
        }),
      ];
      const result = calc(certs, now);
      expect(result.details).toBe('First Class Medical');
    });
  });
});
