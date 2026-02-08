import 'package:flutter/material.dart';
import '../../../models/scratchpad.dart';
import 'template_background.dart';

class DrawingCanvas extends StatelessWidget {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final ScratchPadTemplate template;
  final Map<String, String>? craftHints;
  final void Function(Offset position) onStrokeStart;
  final void Function(Offset position) onStrokeUpdate;
  final VoidCallback onStrokeEnd;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    this.currentStroke,
    required this.template,
    this.craftHints,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => onStrokeStart(details.localPosition),
      onPanUpdate: (details) => onStrokeUpdate(details.localPosition),
      onPanEnd: (_) => onStrokeEnd(),
      child: ClipRect(
        child: CustomPaint(
          painter: _CanvasPainter(
            strokes: strokes,
            currentStroke: currentStroke,
            template: template,
            craftHints: craftHints,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final ScratchPadTemplate template;
  final Map<String, String>? craftHints;

  _CanvasPainter({
    required this.strokes,
    this.currentStroke,
    required this.template,
    this.craftHints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw template background first
    TemplateBackgroundPainter(template, craftHints: craftHints)
        .paint(canvas, size);

    // Draw completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isEraser) {
      paint.blendMode = BlendMode.clear;
      paint.color = Colors.transparent;
    } else {
      paint.color = Color(stroke.colorValue);
    }

    final path = Path();
    path.moveTo(stroke.points[0].x, stroke.points[0].y);

    if (stroke.points.length == 2) {
      path.lineTo(stroke.points[1].x, stroke.points[1].y);
    } else {
      // Smooth the path using quadratic bezier curves
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];
        final midX = (p0.x + p1.x) / 2;
        final midY = (p0.y + p1.y) / 2;
        path.quadraticBezierTo(p0.x, p0.y, midX, midY);
      }
      // Draw to the last point
      final last = stroke.points.last;
      path.lineTo(last.x, last.y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.craftHints != craftHints;
  }
}
