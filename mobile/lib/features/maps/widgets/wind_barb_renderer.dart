import 'dart:typed_data';
import 'dart:math' as math;

/// Generates meteorological wind barb images as RGBA pixel data.
///
/// Uses direct pixel manipulation (no dart:ui Canvas) for reliability
/// during Mapbox style-load callbacks.
///
/// Barb conventions:
/// - Staff points upward (north) from center-bottom; Mapbox rotates by wind direction
/// - Half barb (short line) = 5kt
/// - Full barb (long line) = 10kt
/// - Pennant (filled triangle) = 50kt
/// - Calm = small circle
///
/// Returns premultiplied RGBA data suitable for Mapbox `MbxImage`.
class WindBarbRenderer {
  static Map<String, ({int width, int height, Uint8List data})>? _cache;

  /// Generate all 17 barb images: barb-calm, barb-5 through barb-80.
  static Future<Map<String, ({int width, int height, Uint8List data})>>
      generateAllBarbs({double scale = 2.0}) async {
    if (_cache != null) return _cache!;

    final result = <String, ({int width, int height, Uint8List data})>{};
    final size = (64 * scale).toInt();

    // Calm
    result['barb-calm'] = _renderBarb(speedKt: 0, size: size, scale: scale);

    // 5kt through 80kt in 5kt increments
    for (int kt = 5; kt <= 80; kt += 5) {
      result['barb-$kt'] = _renderBarb(speedKt: kt, size: size, scale: scale);
    }

    _cache = result;
    return result;
  }

  static int _colorForSpeed(int speedKt) {
    if (speedKt < 15) return 0xFF4CAF50; // green
    if (speedKt < 30) return 0xFFFFC107; // yellow
    if (speedKt < 50) return 0xFFFF9800; // orange
    return 0xFFF44336; // red
  }

  static ({int width, int height, Uint8List data}) _renderBarb({
    required int speedKt,
    required int size,
    required double scale,
  }) {
    final pixels = Uint8List(size * size * 4);
    final argb = _colorForSpeed(speedKt);
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final a = (argb >> 24) & 0xFF;

    final cx = size ~/ 2;
    final cy = size ~/ 2;

    void setPixel(int px, int py) {
      if (px < 0 || px >= size || py < 0 || py >= size) return;
      final idx = (py * size + px) * 4;
      // Premultiplied RGBA
      pixels[idx] = (r * a) ~/ 255;
      pixels[idx + 1] = (g * a) ~/ 255;
      pixels[idx + 2] = (b * a) ~/ 255;
      pixels[idx + 3] = a;
    }

    // Draw a thick pixel (circle of given radius)
    void drawThickPixel(int px, int py, int thickness) {
      for (int dy = -thickness; dy <= thickness; dy++) {
        for (int dx = -thickness; dx <= thickness; dx++) {
          if (dx * dx + dy * dy <= thickness * thickness) {
            setPixel(px + dx, py + dy);
          }
        }
      }
    }

    // Bresenham's line with thickness
    void drawLine(double x0d, double y0d, double x1d, double y1d, int thickness) {
      int x0 = x0d.round(), y0 = y0d.round();
      int x1 = x1d.round(), y1 = y1d.round();
      final dx = (x1 - x0).abs();
      final dy = (y1 - y0).abs();
      final sx = x0 < x1 ? 1 : -1;
      final sy = y0 < y1 ? 1 : -1;
      var err = dx - dy;

      while (true) {
        drawThickPixel(x0, y0, thickness);
        if (x0 == x1 && y0 == y1) break;
        final e2 = 2 * err;
        if (e2 > -dy) {
          err -= dy;
          x0 += sx;
        }
        if (e2 < dx) {
          err += dx;
          y0 += sy;
        }
      }
    }

    // Draw a filled triangle
    void drawFilledTriangle(
        double x0, double y0, double x1, double y1, double x2, double y2) {
      // Bounding box
      final minY = math.min(y0, math.min(y1, y2)).floor();
      final maxY = math.max(y0, math.max(y1, y2)).ceil();
      final minX = math.min(x0, math.min(x1, x2)).floor();
      final maxX = math.max(x0, math.max(x1, x2)).ceil();

      for (int py = minY; py <= maxY; py++) {
        for (int px = minX; px <= maxX; px++) {
          if (_pointInTriangle(
              px.toDouble(), py.toDouble(), x0, y0, x1, y1, x2, y2)) {
            setPixel(px, py);
          }
        }
      }
    }

    // Draw a circle outline
    void drawCircle(int centerX, int centerY, double radius, int thickness) {
      final outer = (radius + thickness) * (radius + thickness);
      final inner = math.max(0, (radius - thickness) * (radius - thickness));
      final extent = (radius + thickness).ceil();
      for (int dy = -extent; dy <= extent; dy++) {
        for (int dx = -extent; dx <= extent; dx++) {
          final d2 = (dx * dx + dy * dy).toDouble();
          if (d2 >= inner && d2 <= outer) {
            setPixel(centerX + dx, centerY + dy);
          }
        }
      }
    }

    final thick = (1.5 * scale).round().clamp(1, 4);

    if (speedKt < 3) {
      // Calm: circle
      drawCircle(cx, cy, 6.0 * scale, thick);
    } else {
      // Staff from center-bottom upward
      final staffLen = 24.0 * scale;
      final staffBottom = cy + staffLen * 0.3;
      final staffTop = cy - staffLen * 0.7;
      drawLine(cx.toDouble(), staffBottom, cx.toDouble(), staffTop, thick);

      // Decompose speed
      int remaining = speedKt;
      int pennants = remaining ~/ 50;
      remaining -= pennants * 50;
      int fullBarbs = remaining ~/ 10;
      remaining -= fullBarbs * 10;
      int halfBarbs = remaining ~/ 5;

      // Draw from top down
      double y = staffTop;
      final barbLen = 10.0 * scale;
      final barbSpacing = 4.5 * scale;
      final pennantHeight = 6.0 * scale;

      // Pennants
      for (int i = 0; i < pennants; i++) {
        drawFilledTriangle(
          cx.toDouble(), y,
          cx + barbLen, y + pennantHeight / 2,
          cx.toDouble(), y + pennantHeight,
        );
        y += pennantHeight + 1.0 * scale;
      }

      // Full barbs (angled lines to the right)
      for (int i = 0; i < fullBarbs; i++) {
        drawLine(cx.toDouble(), y, cx + barbLen, y - 4.0 * scale, thick);
        y += barbSpacing;
      }

      // Half barbs
      for (int i = 0; i < halfBarbs; i++) {
        if (pennants == 0 && fullBarbs == 0 && i == 0) {
          y += barbSpacing; // offset down if only element
        }
        drawLine(
            cx.toDouble(), y, cx + barbLen * 0.55, y - 3.0 * scale, thick);
        y += barbSpacing;
      }
    }

    return (width: size, height: size, data: pixels);
  }

  static bool _pointInTriangle(double px, double py, double x0, double y0,
      double x1, double y1, double x2, double y2) {
    final d1 = (px - x1) * (y0 - y1) - (x0 - x1) * (py - y1);
    final d2 = (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2);
    final d3 = (px - x0) * (y2 - y0) - (x2 - x0) * (py - y0);
    final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
    return !(hasNeg && hasPos);
  }
}
