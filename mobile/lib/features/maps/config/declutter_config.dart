/// Centralized configuration for map decluttering behavior.
///
/// All thresholds, zoom levels, and opacity values are defined here
/// so they can be easily tuned without hunting through multiple files.
class DeclutterConfig {
  DeclutterConfig._();

  // ── Airport zoom tiers ──────────────────────────────────────────────────
  // Airports are progressively revealed as the user zooms in.
  // Each tier defines the minimum zoom level at which that category appears.

  /// Tier 1: Towered airports with hard-surface runways (major airports).
  static const double airportZoomToweredHard = 5.0;

  /// Tier 2: Non-towered public airports with hard-surface runways.
  static const double airportZoomHardPublic = 7.0;

  /// Tier 3: Soft-surface airports, heliports, seaplane bases.
  static const double airportZoomSoftHeliSea = 9.0;

  /// Tier 4: Private, military, and other facilities.
  static const double airportZoomOther = 10.0;

  // ── Weather staleness ───────────────────────────────────────────────────
  // METARs, PIREPs, and flight category dots are dimmed based on
  // observation age to indicate decreasing reliability.

  /// Age (minutes) after which weather is considered "aging" — slightly dimmed.
  static const int stalenessAgingMinutes = 60;

  /// Age (minutes) after which weather is considered "stale" — heavily dimmed.
  static const int stalenessStaleMinutes = 120;

  /// Opacity for fresh observations (< agingMinutes old).
  static const double stalenessFreshOpacity = 1.0;

  /// Opacity for aging observations (agingMinutes – staleMinutes).
  static const double stalenessAgingOpacity = 0.65;

  /// Opacity for stale observations (> staleMinutes old).
  static const double stalenessStaleOpacity = 0.35;

  // ── Airspace altitude awareness ─────────────────────────────────────────
  // When a flight plan has a cruise altitude, airspaces whose altitude
  // range doesn't overlap are faded to reduce clutter.

  /// Buffer (feet) above/below cruise altitude to still consider relevant.
  /// e.g., at 8000 ft cruise with 1000 ft buffer, airspaces from 7000–9000
  /// are considered relevant even if cruise isn't strictly inside them.
  static const int airspaceAltitudeBuffer = 1000;

  /// Opacity for airspaces that ARE relevant to cruise altitude.
  static const double airspaceRelevantOpacity = 1.0;

  /// Opacity for airspaces that are NOT relevant to cruise altitude.
  static const double airspaceIrrelevantOpacity = 0.2;

  /// Base fill opacity for airspace polygons (multiplied by per-feature altOpacity).
  static const double airspaceBaseFillOpacity = 0.1;

  /// Base border opacity for airspace lines (multiplied by per-feature altOpacity).
  static const double airspaceBaseBorderOpacity = 0.8;
}
