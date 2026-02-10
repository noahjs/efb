import { WindyService } from './windy.service';

/**
 * Tests for WindyService pure calculation methods.
 * These test navigation math (wind triangle, bearing, distance, ISA temp)
 * and visualization helpers (barb icons, wind colors, angle interpolation).
 */
describe('WindyService — pure functions', () => {
  let service: WindyService;

  beforeEach(() => {
    // Only pure methods are tested — no HTTP calls, so a minimal stub suffices
    service = new WindyService(null as any);
  });

  // ─── computeGroundspeed ───

  describe('computeGroundspeed', () => {
    it('should return TAS when wind speed is zero', () => {
      expect(service.computeGroundspeed(120, 90, 0, 0)).toBe(120);
    });

    it('should reduce GS with a direct headwind', () => {
      // Course 360, wind FROM 360 = direct headwind
      const gs = service.computeGroundspeed(120, 360, 360, 20);
      expect(gs).toBeCloseTo(100, 0);
    });

    it('should increase GS with a direct tailwind', () => {
      // Course 360, wind FROM 180 = direct tailwind
      const gs = service.computeGroundspeed(120, 360, 180, 20);
      expect(gs).toBeCloseTo(140, 0);
    });

    it('should handle a pure crosswind (GS ≈ TAS)', () => {
      // Course 360, wind FROM 090 = pure crosswind
      const gs = service.computeGroundspeed(120, 360, 90, 20);
      // Crosswind causes WCA; GS should be close to but slightly less than TAS
      expect(gs).toBeGreaterThan(110);
      expect(gs).toBeLessThanOrEqual(120);
    });

    it('should compute a known wind triangle', () => {
      // TAS 100, course 090, wind 030@30
      const gs = service.computeGroundspeed(100, 90, 30, 30);
      // Headwind component = 30 * cos(30°-90°) = 30 * cos(-60°) = 15
      // Crosswind component = 30 * sin(-60°) ≈ -26
      // WCA = asin(-26/100) ≈ -15° → cos(WCA) ≈ 0.966
      // GS ≈ 100*0.966 - 15 ≈ 81.6
      expect(gs).toBeGreaterThan(75);
      expect(gs).toBeLessThan(90);
    });

    it('should floor groundspeed at zero for extreme headwind', () => {
      // Wind faster than TAS from directly ahead
      const gs = service.computeGroundspeed(50, 0, 0, 100);
      expect(gs).toBe(0);
    });

    it('should handle wind direction 0 and course 0 (both north)', () => {
      const gs = service.computeGroundspeed(120, 0, 0, 20);
      // Direct headwind
      expect(gs).toBeCloseTo(100, 0);
    });
  });

  // ─── bearing (private — access via prototype) ───

  describe('bearing', () => {
    const bearing = (
      lat1: number,
      lng1: number,
      lat2: number,
      lng2: number,
    ) => (service as any).bearing(lat1, lng1, lat2, lng2);

    it('should return ~0° for due north', () => {
      const brg = bearing(39.0, -104.0, 40.0, -104.0);
      expect(brg).toBeCloseTo(0, 0);
    });

    it('should return ~90° for due east', () => {
      const brg = bearing(39.0, -104.0, 39.0, -103.0);
      expect(brg).toBeCloseTo(90, 0);
    });

    it('should return ~180° for due south', () => {
      const brg = bearing(40.0, -104.0, 39.0, -104.0);
      expect(brg).toBeCloseTo(180, 0);
    });

    it('should return ~270° for due west', () => {
      const brg = bearing(39.0, -103.0, 39.0, -104.0);
      expect(brg).toBeCloseTo(270, 0);
    });

    it('should compute a known city pair (Denver to LA ≈ 242°)', () => {
      // KDEN (39.856, -104.674) → KLAX (33.943, -118.408)
      const brg = bearing(39.856, -104.674, 33.943, -118.408);
      expect(brg).toBeGreaterThan(235);
      expect(brg).toBeLessThan(250);
    });
  });

  // ─── distanceNm (private) ───

  describe('distanceNm', () => {
    const distanceNm = (
      lat1: number,
      lng1: number,
      lat2: number,
      lng2: number,
    ) => (service as any).distanceNm(lat1, lng1, lat2, lng2);

    it('should return 0 for the same point', () => {
      expect(distanceNm(39.0, -104.0, 39.0, -104.0)).toBeCloseTo(0, 5);
    });

    it('should compute 60 NM for 1° latitude change', () => {
      // 1 degree of latitude ≈ 60 NM
      const dist = distanceNm(39.0, -104.0, 40.0, -104.0);
      expect(dist).toBeGreaterThan(59);
      expect(dist).toBeLessThan(61);
    });

    it('should compute a known airport pair distance (KDEN-KCOS ≈ 100 NM)', () => {
      // KDEN (39.856, -104.674) → KCOS (38.806, -104.700)
      const dist = distanceNm(39.856, -104.674, 38.806, -104.7);
      expect(dist).toBeGreaterThan(55);
      expect(dist).toBeLessThan(70);
    });

    it('should compute a longer distance (KDEN-KLAX ≈ 748 NM)', () => {
      const dist = distanceNm(39.856, -104.674, 33.943, -118.408);
      expect(dist).toBeGreaterThan(730);
      expect(dist).toBeLessThan(770);
    });
  });

  // ─── interpolateAngle (private) ───

  describe('interpolateAngle', () => {
    const interpolateAngle = (a: number, b: number, fraction: number) =>
      (service as any).interpolateAngle(a, b, fraction);

    it('should return a at t=0', () => {
      expect(interpolateAngle(90, 180, 0)).toBeCloseTo(90, 5);
    });

    it('should return b at t=1', () => {
      expect(interpolateAngle(90, 180, 1)).toBeCloseTo(180, 5);
    });

    it('should return midpoint for t=0.5', () => {
      expect(interpolateAngle(90, 180, 0.5)).toBeCloseTo(135, 5);
    });

    it('should handle 350° to 10° wrap-around', () => {
      // Shortest path 350 → 10 is 20° clockwise, midpoint = 0
      const mid = interpolateAngle(350, 10, 0.5);
      expect(mid).toBeCloseTo(0, 0);
    });

    it('should handle 10° to 350° wrap-around', () => {
      // Shortest path 10 → 350 is 20° counter-clockwise, midpoint = 0
      const mid = interpolateAngle(10, 350, 0.5);
      expect(mid).toBeCloseTo(0, 0);
    });

    it('should handle 0° to 0°', () => {
      expect(interpolateAngle(0, 0, 0.5)).toBeCloseTo(0, 5);
    });
  });

  // ─── isaTemperature (private) ───

  describe('isaTemperature', () => {
    const isaTemperature = (altFt: number) =>
      (service as any).isaTemperature(altFt);

    it('should return 15°C at sea level', () => {
      expect(isaTemperature(0)).toBeCloseTo(15, 1);
    });

    it('should return ~-20.6°C at FL180', () => {
      // 15 - 1.98 * 18 = 15 - 35.64 = -20.64
      expect(isaTemperature(18000)).toBeCloseTo(-20.64, 1);
    });

    it('should return ~-54.3°C at FL350', () => {
      // 15 - 1.98 * 35 = 15 - 69.3 = -54.3
      expect(isaTemperature(35000)).toBeCloseTo(-54.3, 1);
    });

    it('should return -56.5°C at and above the tropopause (FL360)', () => {
      expect(isaTemperature(36089)).toBe(-56.5);
      expect(isaTemperature(45000)).toBe(-56.5);
    });
  });

  // ─── barbIconName (private) ───

  describe('barbIconName', () => {
    const barbIconName = (speedKt: number) =>
      (service as any).barbIconName(speedKt);

    it('should return barb-calm for winds < 3 kt', () => {
      expect(barbIconName(0)).toBe('barb-calm');
      expect(barbIconName(2)).toBe('barb-calm');
    });

    it('should round to nearest 5 kt', () => {
      expect(barbIconName(3)).toBe('barb-5');
      expect(barbIconName(7)).toBe('barb-5');
      expect(barbIconName(8)).toBe('barb-10');
      expect(barbIconName(12)).toBe('barb-10');
      expect(barbIconName(13)).toBe('barb-15');
      expect(barbIconName(25)).toBe('barb-25');
    });

    it('should cap at barb-80 for very high winds', () => {
      expect(barbIconName(100)).toBe('barb-80');
      expect(barbIconName(80)).toBe('barb-80');
    });
  });

  // ─── windSpeedColor (private) ───

  describe('windSpeedColor', () => {
    const windSpeedColor = (speedKt: number) =>
      (service as any).windSpeedColor(speedKt);

    it('should return green for light winds (< 15 kt)', () => {
      expect(windSpeedColor(0)).toBe('#4CAF50');
      expect(windSpeedColor(14)).toBe('#4CAF50');
    });

    it('should return yellow for moderate winds (15-29 kt)', () => {
      expect(windSpeedColor(15)).toBe('#FFC107');
      expect(windSpeedColor(29)).toBe('#FFC107');
    });

    it('should return orange for strong winds (30-49 kt)', () => {
      expect(windSpeedColor(30)).toBe('#FF9800');
      expect(windSpeedColor(49)).toBe('#FF9800');
    });

    it('should return red for severe winds (≥ 50 kt)', () => {
      expect(windSpeedColor(50)).toBe('#F44336');
      expect(windSpeedColor(100)).toBe('#F44336');
    });
  });
});
