import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Generates VFR sectional chart-style airport symbols using dart:ui Canvas
/// for high-quality anti-aliased rendering.
///
/// Symbol types follow FAA VFR sectional chart conventions:
/// - Hard surface: open circle with runway bar through center
/// - Soft surface: filled circle (no bar)
/// - Towered: blue color
/// - Non-towered: magenta color
/// - Serviced (fuel): tick marks at cardinal directions
/// - Private: circle with "R"
/// - Heliport: circle with "H"
/// - Seaplane: circle with anchor symbol
/// - Military: red color
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

  // FAA VFR chart colors (brightened for dark-map visibility)
  static const _blue = ui.Color(0xFF3264EB); // Towered
  static const _magenta = ui.Color(0xFFC832DC); // Non-towered
  static const _red = ui.Color(0xFFDC4646); // Military
  static const _gray = ui.Color(0xFF969696); // Unknown

  /// Generate all airport symbol images.
  static Future<Map<String, ({int width, int height, Uint8List data})>>
      generateAllSymbols({double scale = 2.0}) async {
    if (_cache != null) return _cache!;

    final s = (40 * scale).toInt();
    final result = <String, ({int width, int height, Uint8List data})>{};

    result['apt-hard-t-s'] =
        await _renderHardSurface(s, _blue, serviced: true);
    result['apt-hard-t-ns'] =
        await _renderHardSurface(s, _blue, serviced: false);
    result['apt-hard-nt-s'] =
        await _renderHardSurface(s, _magenta, serviced: true);
    result['apt-hard-nt-ns'] =
        await _renderHardSurface(s, _magenta, serviced: false);
    result['apt-soft-s'] =
        await _renderSoftSurface(s, _magenta, serviced: true);
    result['apt-soft-ns'] =
        await _renderSoftSurface(s, _magenta, serviced: false);
    result['apt-private'] = await _renderLetterSymbol(s, _magenta, 'R');
    result['apt-heliport'] = await _renderLetterSymbol(s, _magenta, 'H');
    result['apt-seaplane'] = await _renderSeaplane(s, _magenta);
    result['apt-military-s'] =
        await _renderHardSurface(s, _red, serviced: true);
    result['apt-military-ns'] =
        await _renderHardSurface(s, _red, serviced: false);
    result['apt-unknown'] =
        await _renderSoftSurface(s, _gray, serviced: false);

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

  // ── Canvas rendering ──

  /// Renders a drawing function to RGBA pixel data via dart:ui Canvas.
  static Future<({int width, int height, Uint8List data})> _render(
    int size,
    void Function(ui.Canvas canvas, double s) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    draw(canvas, size.toDouble());
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    return (
      width: size,
      height: size,
      data: Uint8List.fromList(byteData!.buffer.asUint8List()),
    );
  }

  // ── Paint helpers ──

  static ui.Paint _stroke(ui.Color color, double width,
      [ui.StrokeCap cap = ui.StrokeCap.butt]) {
    return ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap
      ..color = color
      ..isAntiAlias = true;
  }

  static ui.Paint _fill(ui.Color color) {
    return ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;
  }

  // ── Symbol renderers ──

  /// Hard surface airport: open circle with runway bar through center.
  static Future<({int width, int height, Uint8List data})> _renderHardSurface(
    int size,
    ui.Color color, {
    required bool serviced,
  }) {
    return _render(size, (canvas, s) {
      final c = ui.Offset(s / 2, s / 2);
      final r = s * 0.28;
      final sw = math.max(1.5, s * 0.055);
      final barExt = s * 0.42;
      final tickLen = s * 0.13;

      // White fill for contrast on dark maps
      canvas.drawCircle(
          c, r - sw / 2, _fill(const ui.Color(0xD9FFFFFF)));

      // Circle outline
      canvas.drawCircle(c, r, _stroke(color, sw));

      // Horizontal runway bar extending beyond circle
      canvas.drawLine(
        ui.Offset(c.dx - barExt, c.dy),
        ui.Offset(c.dx + barExt, c.dy),
        _stroke(color, sw),
      );

      if (serviced) {
        _drawTicks(canvas, c, r, tickLen, color, sw);
      }
    });
  }

  /// Soft surface airport: filled circle (no runway bar).
  static Future<({int width, int height, Uint8List data})> _renderSoftSurface(
    int size,
    ui.Color color, {
    required bool serviced,
  }) {
    return _render(size, (canvas, s) {
      final c = ui.Offset(s / 2, s / 2);
      final r = s * 0.20;
      final sw = math.max(1.5, s * 0.055);
      final tickLen = s * 0.13;

      // Filled solid circle
      canvas.drawCircle(c, r, _fill(color));

      if (serviced) {
        _drawTicks(canvas, c, r, tickLen, color, sw);
      }
    });
  }

  /// Letter symbol (R for restricted/private, H for heliport).
  static Future<({int width, int height, Uint8List data})> _renderLetterSymbol(
    int size,
    ui.Color color,
    String letter,
  ) {
    return _render(size, (canvas, s) {
      final c = ui.Offset(s / 2, s / 2);
      final r = s * 0.30;
      final sw = math.max(1.5, s * 0.055);

      // White fill
      canvas.drawCircle(
          c, r - sw / 2, _fill(const ui.Color(0xD9FFFFFF)));

      // Circle outline
      canvas.drawCircle(c, r, _stroke(color, sw));

      // Draw letter
      final lw = sw * 0.85;
      if (letter == 'H') {
        _drawH(canvas, c, r, color, lw);
      } else if (letter == 'R') {
        _drawR(canvas, c, r, color, lw);
      }
    });
  }

  /// Seaplane base: circle with anchor symbol.
  static Future<({int width, int height, Uint8List data})> _renderSeaplane(
    int size,
    ui.Color color,
  ) {
    return _render(size, (canvas, s) {
      final c = ui.Offset(s / 2, s / 2);
      final r = s * 0.30;
      final sw = math.max(1.5, s * 0.055);

      // White fill
      canvas.drawCircle(
          c, r - sw / 2, _fill(const ui.Color(0xD9FFFFFF)));

      // Circle outline
      canvas.drawCircle(c, r, _stroke(color, sw));

      // Anchor symbol
      _drawAnchor(canvas, c, r, color, sw * 0.85);
    });
  }

  // ── Drawing helpers ──

  /// Draw service tick marks at cardinal directions (N, S, E, W).
  static void _drawTicks(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    double tickLen,
    ui.Color color,
    double strokeWidth,
  ) {
    final paint = _stroke(color, strokeWidth);
    final cx = center.dx;
    final cy = center.dy;
    // North
    canvas.drawLine(
        ui.Offset(cx, cy - radius), ui.Offset(cx, cy - radius - tickLen), paint);
    // South
    canvas.drawLine(
        ui.Offset(cx, cy + radius), ui.Offset(cx, cy + radius + tickLen), paint);
    // East
    canvas.drawLine(
        ui.Offset(cx + radius, cy), ui.Offset(cx + radius + tickLen, cy), paint);
    // West
    canvas.drawLine(
        ui.Offset(cx - radius, cy), ui.Offset(cx - radius - tickLen, cy), paint);
  }

  /// Draw letter "H" centered at offset (heliport symbol).
  static void _drawH(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    ui.Color color,
    double strokeWidth,
  ) {
    final hh = radius * 0.52;
    final hw = radius * 0.38;
    final cx = center.dx;
    final cy = center.dy;
    final paint = _stroke(color, strokeWidth);
    // Left vertical
    canvas.drawLine(ui.Offset(cx - hw, cy - hh), ui.Offset(cx - hw, cy + hh), paint);
    // Right vertical
    canvas.drawLine(ui.Offset(cx + hw, cy - hh), ui.Offset(cx + hw, cy + hh), paint);
    // Crossbar
    canvas.drawLine(ui.Offset(cx - hw, cy), ui.Offset(cx + hw, cy), paint);
  }

  /// Draw letter "R" centered at offset (restricted/private symbol).
  static void _drawR(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    ui.Color color,
    double strokeWidth,
  ) {
    final hh = radius * 0.52;
    final hw = radius * 0.32;
    final cx = center.dx;
    final cy = center.dy;
    final paint = _stroke(color, strokeWidth);

    // Vertical stem
    canvas.drawLine(
        ui.Offset(cx - hw, cy - hh), ui.Offset(cx - hw, cy + hh), paint);

    // Top bump using path (rounded top-right)
    final bumpW = hw * 1.3;
    final bumpPath = ui.Path()
      ..moveTo(cx - hw, cy - hh)
      ..lineTo(cx - hw + bumpW * 0.5, cy - hh)
      ..quadraticBezierTo(
          cx - hw + bumpW, cy - hh, cx - hw + bumpW, cy - hh / 2)
      ..quadraticBezierTo(
          cx - hw + bumpW, cy, cx - hw + bumpW * 0.5, cy)
      ..lineTo(cx - hw, cy);
    canvas.drawPath(bumpPath, paint);

    // Diagonal leg (from middle junction to bottom-right)
    canvas.drawLine(
        ui.Offset(cx - hw + bumpW * 0.3, cy),
        ui.Offset(cx + hw, cy + hh),
        paint);
  }

  /// Draw an anchor symbol centered at offset (seaplane base).
  static void _drawAnchor(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    ui.Color color,
    double strokeWidth,
  ) {
    final stemH = radius * 0.50;
    final crossW = radius * 0.35;
    final cx = center.dx;
    final cy = center.dy;
    final paint = _stroke(color, strokeWidth, ui.StrokeCap.round);

    // Ring at top
    final ringR = strokeWidth * 1.3;
    canvas.drawCircle(
      ui.Offset(cx, cy - stemH - ringR),
      ringR,
      _stroke(color, strokeWidth * 0.7),
    );

    // Vertical stem
    canvas.drawLine(
      ui.Offset(cx, cy - stemH),
      ui.Offset(cx, cy + stemH * 0.7),
      paint,
    );

    // Horizontal crossbar near top
    final crossY = cy - stemH * 0.3;
    canvas.drawLine(
      ui.Offset(cx - crossW, crossY),
      ui.Offset(cx + crossW, crossY),
      paint,
    );

    // Curved flukes at bottom
    final flukeY = cy + stemH * 0.7;
    final flukePath = ui.Path()
      ..moveTo(cx - crossW, flukeY - crossW * 0.5)
      ..quadraticBezierTo(
          cx - crossW * 0.2, flukeY + crossW * 0.5, cx, flukeY)
      ..quadraticBezierTo(
          cx + crossW * 0.2, flukeY + crossW * 0.5, cx + crossW, flukeY - crossW * 0.5);
    canvas.drawPath(flukePath, paint);
  }
}
