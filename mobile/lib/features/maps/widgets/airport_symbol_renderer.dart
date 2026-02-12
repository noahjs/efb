import 'dart:typed_data';
import 'dart:math' as math;

/// Generates VFR chart-style airport symbols as RGBA pixel data.
///
/// Uses direct pixel manipulation (no dart:ui Canvas) for reliability
/// during Mapbox style-load callbacks.
///
/// Symbol types follow standard FAA VFR sectional chart conventions:
/// - Hard surface: circle with runway bar through center
/// - Soft surface: filled circle (no bar)
/// - Towered: blue color
/// - Non-towered: magenta color
/// - Serviced (fuel): tick marks at cardinal directions
/// - Private: circle with "R"
/// - Heliport: circle with "H"
/// - Seaplane: circle with anchor/wave
/// - Military: red/orange color
class AirportSymbolRenderer {
  static Map<String, ({int width, int height, Uint8List data})>? _cache;

  /// All symbol type names that will be generated.
  static const symbolTypes = [
    'apt-hard-t-s', // Hard surface, towered, serviced
    'apt-hard-t-ns', // Hard surface, towered, non-serviced
    'apt-hard-nt-s', // Hard surface, non-towered, serviced
    'apt-hard-nt-ns', // Hard surface, non-towered, non-serviced
    'apt-soft-s', // Soft surface, serviced
    'apt-soft-ns', // Soft surface, non-serviced
    'apt-private', // Private airport
    'apt-heliport', // Heliport
    'apt-seaplane', // Seaplane base
    'apt-military-s', // Military, serviced
    'apt-military-ns', // Military, non-serviced
    'apt-unknown', // Unknown/fallback
  ];

  // Colors (RGBA)
  static const _magenta = (r: 200, g: 50, b: 220, a: 255); // Non-towered
  static const _blue = (r: 50, g: 100, b: 235, a: 255); // Towered
  static const _red = (r: 220, g: 70, b: 70, a: 255); // Military
  static const _gray = (r: 150, g: 150, b: 150, a: 255); // Unknown
  static const _white = (r: 255, g: 255, b: 255, a: 255);

  /// Generate all airport symbol images.
  static Future<Map<String, ({int width, int height, Uint8List data})>>
      generateAllSymbols({double scale = 2.0}) async {
    if (_cache != null) return _cache!;

    final s = (40 * scale).toInt(); // Image size
    final result = <String, ({int width, int height, Uint8List data})>{};

    // Hard surface, towered, serviced
    result['apt-hard-t-s'] = _renderHardSurface(s, _blue, serviced: true, filled: true);
    // Hard surface, towered, non-serviced
    result['apt-hard-t-ns'] = _renderHardSurface(s, _blue, serviced: false, filled: true);
    // Hard surface, non-towered, serviced
    result['apt-hard-nt-s'] = _renderHardSurface(s, _magenta, serviced: true, filled: false);
    // Hard surface, non-towered, non-serviced
    result['apt-hard-nt-ns'] = _renderHardSurface(s, _magenta, serviced: false, filled: false);
    // Soft surface, serviced
    result['apt-soft-s'] = _renderSoftSurface(s, _magenta, serviced: true);
    // Soft surface, non-serviced
    result['apt-soft-ns'] = _renderSoftSurface(s, _magenta, serviced: false);
    // Private
    result['apt-private'] = _renderLetterSymbol(s, _magenta, 'R');
    // Heliport
    result['apt-heliport'] = _renderLetterSymbol(s, _magenta, 'H');
    // Seaplane
    result['apt-seaplane'] = _renderSeaplane(s, _magenta);
    // Military serviced
    result['apt-military-s'] = _renderHardSurface(s, _red, serviced: true, filled: true);
    // Military non-serviced
    result['apt-military-ns'] = _renderHardSurface(s, _red, serviced: false, filled: true);
    // Unknown
    result['apt-unknown'] = _renderSoftSurface(s, _gray, serviced: false);

    _cache = result;
    return result;
  }

  /// Determine the symbol type for an airport based on its properties.
  static String classifyAirport(Map<String, dynamic> airport) {
    final facilityType = (airport['facility_type'] ?? 'A').toString();
    final facilityUse = (airport['facility_use'] ?? 'PU').toString();
    final ownershipType = (airport['ownership_type'] ?? '').toString();
    final hasHardSurface = airport['has_hard_surface'] ?? true;
    final hasTower = airport['has_tower'];
    final towerHours = airport['tower_hours'];
    final fuelTypes = airport['fuel_types'];

    // Special facility types
    if (facilityType == 'H') return 'apt-heliport';
    if (facilityType == 'S') return 'apt-seaplane';

    // Private airports
    if (facilityUse == 'PR') return 'apt-private';

    // Determine attributes
    final isMilitary = ownershipType.startsWith('M');
    final isTowered = hasTower == true ||
        (towerHours != null && towerHours.toString().trim().isNotEmpty);
    final isServiced = fuelTypes != null && fuelTypes.toString().trim().isNotEmpty;

    if (isMilitary) {
      return isServiced ? 'apt-military-s' : 'apt-military-ns';
    }

    if (hasHardSurface == true) {
      if (isTowered) {
        return isServiced ? 'apt-hard-t-s' : 'apt-hard-t-ns';
      }
      return isServiced ? 'apt-hard-nt-s' : 'apt-hard-nt-ns';
    }

    // Soft surface (towered soft surface airports are rare, treat same as non-towered)
    return isServiced ? 'apt-soft-s' : 'apt-soft-ns';
  }

  // ── Rendering helpers ──

  /// Hard surface airport: circle with runway bar.
  /// [filled] = true for towered (filled interior), false for non-towered (outline only).
  static ({int width, int height, Uint8List data}) _renderHardSurface(
    int size,
    ({int r, int g, int b, int a}) color, {
    required bool serviced,
    required bool filled,
  }) {
    final buf = Uint8List(size * size * 4);
    final cx = size ~/ 2;
    final cy = size ~/ 2;
    final radius = (size * 0.30).round(); // Main circle radius
    final barHalf = (size * 0.42).round(); // Bar extends beyond circle
    final thickness = math.max(2, (size * 0.06).round());
    final tickLen = (size * 0.12).round();

    // White fill for readability against dark map
    if (filled) {
      _fillCircle(buf, size, cx, cy, radius - thickness, _white);
    } else {
      _fillCircle(buf, size, cx, cy, radius - thickness,
          (r: 255, g: 255, b: 255, a: 180));
    }

    // Circle outline
    _strokeCircle(buf, size, cx, cy, radius, color, thickness);

    // Horizontal runway bar
    _fillRect(buf, size,
        cx - barHalf, cy - thickness ~/ 2,
        barHalf * 2 + 1, thickness,
        color);

    // Serviced tick marks at N, S, E, W
    if (serviced) {
      // North tick
      _fillRect(buf, size,
          cx - thickness ~/ 2, cy - radius - tickLen,
          thickness, tickLen,
          color);
      // South tick
      _fillRect(buf, size,
          cx - thickness ~/ 2, cy + radius + 1,
          thickness, tickLen,
          color);
      // East tick
      _fillRect(buf, size,
          cx + radius + 1, cy - thickness ~/ 2,
          tickLen, thickness,
          color);
      // West tick
      _fillRect(buf, size,
          cx - radius - tickLen, cy - thickness ~/ 2,
          tickLen, thickness,
          color);
    }

    return (width: size, height: size, data: buf);
  }

  /// Soft surface airport: filled circle (no runway bar).
  static ({int width, int height, Uint8List data}) _renderSoftSurface(
    int size,
    ({int r, int g, int b, int a}) color, {
    required bool serviced,
  }) {
    final buf = Uint8List(size * size * 4);
    final cx = size ~/ 2;
    final cy = size ~/ 2;
    final radius = (size * 0.22).round(); // Smaller than hard surface
    final thickness = math.max(2, (size * 0.06).round());
    final tickLen = (size * 0.12).round();

    // Filled circle
    _fillCircle(buf, size, cx, cy, radius, color);

    if (serviced) {
      // North tick
      _fillRect(buf, size,
          cx - thickness ~/ 2, cy - radius - tickLen,
          thickness, tickLen,
          color);
      // South tick
      _fillRect(buf, size,
          cx - thickness ~/ 2, cy + radius + 1,
          thickness, tickLen,
          color);
      // East tick
      _fillRect(buf, size,
          cx + radius + 1, cy - thickness ~/ 2,
          tickLen, thickness,
          color);
      // West tick
      _fillRect(buf, size,
          cx - radius - tickLen, cy - thickness ~/ 2,
          tickLen, thickness,
          color);
    }

    return (width: size, height: size, data: buf);
  }

  /// Letter symbol (R for private, H for heliport).
  static ({int width, int height, Uint8List data}) _renderLetterSymbol(
    int size,
    ({int r, int g, int b, int a}) color,
    String letter,
  ) {
    final buf = Uint8List(size * size * 4);
    final cx = size ~/ 2;
    final cy = size ~/ 2;
    final radius = (size * 0.30).round();
    final thickness = math.max(2, (size * 0.06).round());

    // White fill
    _fillCircle(buf, size, cx, cy, radius - thickness,
        (r: 255, g: 255, b: 255, a: 200));

    // Circle outline
    _strokeCircle(buf, size, cx, cy, radius, color, thickness);

    // Draw letter
    if (letter == 'H') {
      _drawLetterH(buf, size, cx, cy, radius, color, thickness);
    } else if (letter == 'R') {
      _drawLetterR(buf, size, cx, cy, radius, color, thickness);
    }

    return (width: size, height: size, data: buf);
  }

  /// Seaplane base: circle with anchor/wave symbol.
  static ({int width, int height, Uint8List data}) _renderSeaplane(
    int size,
    ({int r, int g, int b, int a}) color,
  ) {
    final buf = Uint8List(size * size * 4);
    final cx = size ~/ 2;
    final cy = size ~/ 2;
    final radius = (size * 0.30).round();
    final thickness = math.max(2, (size * 0.06).round());

    // White fill
    _fillCircle(buf, size, cx, cy, radius - thickness,
        (r: 255, g: 255, b: 255, a: 200));

    // Circle outline
    _strokeCircle(buf, size, cx, cy, radius, color, thickness);

    // Draw anchor: vertical line + crossbar + curved bottom
    final lineHalf = (radius * 0.6).round();
    // Vertical stem
    _fillRect(buf, size,
        cx - thickness ~/ 2, cy - lineHalf,
        thickness, lineHalf * 2,
        color);
    // Crossbar near top
    final crossY = cy - (lineHalf * 0.5).round();
    final crossHalf = (lineHalf * 0.5).round();
    _fillRect(buf, size,
        cx - crossHalf, crossY - thickness ~/ 2,
        crossHalf * 2 + 1, thickness,
        color);
    // Small ring at top
    _strokeCircle(buf, size, cx, cy - lineHalf - 1, 2, color, 1);
    // Curved flukes at bottom (small arcs left and right)
    final flukeY = cy + lineHalf;
    for (int dx = -crossHalf; dx <= crossHalf; dx++) {
      final dy = -(math.sqrt(math.max(0, crossHalf * crossHalf - dx * dx))).round();
      _setPixelSafe(buf, size, cx + dx, flukeY + dy + crossHalf ~/ 2, color);
      if (thickness > 1) {
        _setPixelSafe(buf, size, cx + dx, flukeY + dy + crossHalf ~/ 2 + 1, color);
      }
    }

    return (width: size, height: size, data: buf);
  }

  // ── Drawing primitives ──

  static void _setPixelSafe(
    Uint8List buf, int size, int x, int y,
    ({int r, int g, int b, int a}) color,
  ) {
    if (x < 0 || x >= size || y < 0 || y >= size) return;
    final idx = (y * size + x) * 4;
    buf[idx] = color.r;
    buf[idx + 1] = color.g;
    buf[idx + 2] = color.b;
    buf[idx + 3] = color.a;
  }

  static void _fillCircle(
    Uint8List buf, int size, int cx, int cy, int radius,
    ({int r, int g, int b, int a}) color,
  ) {
    final r2 = radius * radius;
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy <= r2) {
          _setPixelSafe(buf, size, cx + dx, cy + dy, color);
        }
      }
    }
  }

  static void _strokeCircle(
    Uint8List buf, int size, int cx, int cy, int radius,
    ({int r, int g, int b, int a}) color, int thickness,
  ) {
    final outerR2 = radius * radius;
    final innerR = radius - thickness;
    final innerR2 = innerR * innerR;
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final d2 = dx * dx + dy * dy;
        if (d2 <= outerR2 && d2 >= innerR2) {
          _setPixelSafe(buf, size, cx + dx, cy + dy, color);
        }
      }
    }
  }

  static void _fillRect(
    Uint8List buf, int size,
    int x, int y, int w, int h,
    ({int r, int g, int b, int a}) color,
  ) {
    for (int dy = 0; dy < h; dy++) {
      for (int dx = 0; dx < w; dx++) {
        _setPixelSafe(buf, size, x + dx, y + dy, color);
      }
    }
  }

  /// Draw letter "H" centered at (cx, cy).
  static void _drawLetterH(
    Uint8List buf, int size, int cx, int cy, int radius,
    ({int r, int g, int b, int a}) color, int thickness,
  ) {
    final halfH = (radius * 0.55).round();
    final halfW = (radius * 0.40).round();

    // Left vertical
    _fillRect(buf, size,
        cx - halfW - thickness ~/ 2, cy - halfH,
        thickness, halfH * 2 + 1,
        color);
    // Right vertical
    _fillRect(buf, size,
        cx + halfW - thickness ~/ 2, cy - halfH,
        thickness, halfH * 2 + 1,
        color);
    // Horizontal crossbar
    _fillRect(buf, size,
        cx - halfW, cy - thickness ~/ 2,
        halfW * 2 + 1, thickness,
        color);
  }

  /// Draw letter "R" centered at (cx, cy).
  static void _drawLetterR(
    Uint8List buf, int size, int cx, int cy, int radius,
    ({int r, int g, int b, int a}) color, int thickness,
  ) {
    final halfH = (radius * 0.55).round();
    final halfW = (radius * 0.35).round();

    // Vertical stem (left side)
    _fillRect(buf, size,
        cx - halfW, cy - halfH,
        thickness, halfH * 2 + 1,
        color);

    // Top horizontal bar
    _fillRect(buf, size,
        cx - halfW, cy - halfH,
        halfW * 2, thickness,
        color);

    // Middle horizontal bar
    _fillRect(buf, size,
        cx - halfW, cy - thickness ~/ 2,
        halfW * 2, thickness,
        color);

    // Right side of bump (top half, from top bar to middle bar)
    _fillRect(buf, size,
        cx + halfW - thickness, cy - halfH,
        thickness, halfH + 1,
        color);

    // Diagonal leg (from middle to bottom-right)
    final legLen = halfH;
    for (int i = 0; i <= legLen; i++) {
      final px = cx - thickness ~/ 2 + (i * halfW ~/ legLen);
      final py = cy + i;
      _fillRect(buf, size, px, py, thickness, 1, color);
    }
  }
}
