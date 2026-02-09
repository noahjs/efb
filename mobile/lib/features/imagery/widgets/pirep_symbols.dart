import 'package:flutter/material.dart';

/// Standard aviation PIREP symbol shapes.
/// - Triangle (inverted): turbulence
/// - Diamond: icing
/// - Circle: smooth/negative/other
enum PirepShape { circle, triangle, diamond }

/// Determines the Mapbox icon name for a PIREP feature.
///
/// Turbulence takes priority over icing for shape selection.
/// Severity determines fill (outlined = light, filled = mod/sev).
String pirepIconName(Map<String, dynamic> props) {
  final tbInt = (props['tbInt1'] as String? ?? '').toUpperCase();
  final icgInt = (props['icgInt1'] as String? ?? '').toUpperCase();

  if (_isSignificant(tbInt)) {
    return 'pirep-turb-${_severityTag(tbInt)}';
  }
  if (_isSignificant(icgInt)) {
    return 'pirep-ice-${_severityTag(icgInt)}';
  }
  if (tbInt == 'NEG' || tbInt == 'SMTH' || tbInt == 'SMOOTH' ||
      icgInt == 'NEG' || icgInt == 'NONE' || icgInt == 'TRACE') {
    return 'pirep-neg';
  }
  return 'pirep-none';
}

bool _isSignificant(String intensity) {
  switch (intensity) {
    case 'LGT':
    case 'LIGHT':
    case 'LGT-MOD':
    case 'MOD':
    case 'MODERATE':
    case 'MOD-SEV':
    case 'SEV':
    case 'SEVERE':
    case 'SEV-EXTM':
    case 'EXTM':
    case 'EXTREME':
      return true;
    default:
      return false;
  }
}

String _severityTag(String intensity) {
  switch (intensity) {
    case 'LGT':
    case 'LIGHT':
    case 'LGT-MOD':
      return 'lgt';
    case 'MOD':
    case 'MODERATE':
    case 'MOD-SEV':
      return 'mod';
    default:
      return 'sev';
  }
}

/// Draws a PIREP symbol on a Flutter canvas.
///
/// Set [withOutline] to add a white outline for map icon contrast.
void drawPirepSymbol(
  Canvas canvas,
  double size,
  PirepShape shape,
  Color color,
  bool filled, {
  bool withOutline = false,
}) {
  switch (shape) {
    case PirepShape.triangle:
      _drawTriangle(canvas, size, color, filled, withOutline);
    case PirepShape.diamond:
      _drawDiamond(canvas, size, color, filled, withOutline);
    case PirepShape.circle:
      _drawPirepCircle(canvas, size, color, withOutline);
  }
}

void _drawTriangle(
    Canvas canvas, double s, Color color, bool filled, bool withOutline) {
  final path = Path()
    ..moveTo(s * 0.5, s * 0.85) // bottom center
    ..lineTo(s * 0.12, s * 0.15) // top left
    ..lineTo(s * 0.88, s * 0.15) // top right
    ..close();

  if (withOutline) {
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x99FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.14
          ..strokeJoin = StrokeJoin.round);
  }

  canvas.drawPath(
      path,
      Paint()
        ..color = filled ? color : color.withValues(alpha: 0.3));

  canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07
        ..strokeJoin = StrokeJoin.round);
}

void _drawDiamond(
    Canvas canvas, double s, Color color, bool filled, bool withOutline) {
  final path = Path()
    ..moveTo(s * 0.5, s * 0.08) // top
    ..lineTo(s * 0.88, s * 0.5) // right
    ..lineTo(s * 0.5, s * 0.92) // bottom
    ..lineTo(s * 0.12, s * 0.5) // left
    ..close();

  if (withOutline) {
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x99FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.14
          ..strokeJoin = StrokeJoin.round);
  }

  canvas.drawPath(
      path,
      Paint()
        ..color = filled ? color : color.withValues(alpha: 0.3));

  canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07
        ..strokeJoin = StrokeJoin.round);
}

void _drawPirepCircle(
    Canvas canvas, double s, Color color, bool withOutline) {
  final center = Offset(s / 2, s / 2);
  final radius = s * 0.35;

  if (withOutline) {
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0x99FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.12);
  }

  canvas.drawCircle(center, radius, Paint()..color = color);
  canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07);
}

/// CustomPainter for drawing PIREP symbols in Flutter widgets (legend, etc.).
class PirepSymbolPainter extends CustomPainter {
  final PirepShape shape;
  final Color color;
  final bool filled;

  const PirepSymbolPainter({
    required this.shape,
    required this.color,
    this.filled = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    drawPirepSymbol(canvas, size.width, shape, color, filled);
  }

  @override
  bool shouldRepaint(PirepSymbolPainter oldDelegate) =>
      shape != oldDelegate.shape ||
      color != oldDelegate.color ||
      filled != oldDelegate.filled;
}
