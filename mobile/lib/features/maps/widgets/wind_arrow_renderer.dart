import 'dart:typed_data';
import 'dart:math' as math;

/// Generates a directional arrow icon as SDF RGBA pixel data.
///
/// Produces a filled triangle pointing upward (north). Mapbox rotates it
/// by the `rotation` property. Registered as SDF so `icon-color` can
/// dynamically tint it based on wind speed.
///
/// Returns premultiplied RGBA data suitable for Mapbox `MbxImage`.
class WindArrowRenderer {
  static ({int width, int height, Uint8List data})? _cache;

  /// Generate the wind arrow SDF image (48x48 at 2x scale = 96x96 pixels).
  static ({int width, int height, Uint8List data}) generateArrow({
    double scale = 2.0,
  }) {
    if (_cache != null) return _cache!;

    final size = (48 * scale).toInt();
    final pixels = Uint8List(size * size * 4);

    // Draw a filled triangle pointing upward:
    //   tip at (center, top+padding)
    //   base corners at (center-halfBase, bottom-padding) and (center+halfBase, bottom-padding)
    final cx = size / 2;
    final topPad = size * 0.12;
    final bottomPad = size * 0.15;
    final halfBase = size * 0.30;

    // Triangle vertices
    final tipX = cx;
    final tipY = topPad;
    final leftX = cx - halfBase;
    final leftY = size - bottomPad;
    final rightX = cx + halfBase;
    final rightY = size - bottomPad;

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        if (_pointInTriangle(
          x.toDouble(),
          y.toDouble(),
          tipX,
          tipY,
          leftX,
          leftY,
          rightX,
          rightY,
        )) {
          final idx = (y * size + x) * 4;
          // SDF: white pixel with full alpha — Mapbox applies icon-color
          pixels[idx] = 0xFF;
          pixels[idx + 1] = 0xFF;
          pixels[idx + 2] = 0xFF;
          pixels[idx + 3] = 0xFF;
        }
      }
    }

    final result = (width: size, height: size, data: pixels);
    _cache = result;
    return result;
  }

  static bool _pointInTriangle(
    double px,
    double py,
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final d1 = (px - x1) * (y0 - y1) - (x0 - x1) * (py - y1);
    final d2 = (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2);
    final d3 = (px - x0) * (y2 - y0) - (x2 - x0) * (py - y0);
    final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
    return !(hasNeg && hasPos);
  }
}
