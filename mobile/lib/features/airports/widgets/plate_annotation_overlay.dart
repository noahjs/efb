import 'package:flutter/material.dart';
import '../../../models/scratchpad.dart';

/// Transparent drawing overlay for approach plate annotations.
///
/// When [isDrawing] is false, existing strokes are painted but all gestures
/// pass through to the underlying PDFView. When [isDrawing] is true, pan
/// gestures are intercepted for drawing.
class PlateAnnotationOverlay extends StatelessWidget {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final bool isDrawing;
  final void Function(Offset position)? onStrokeStart;
  final void Function(Offset position)? onStrokeUpdate;
  final VoidCallback? onStrokeEnd;

  const PlateAnnotationOverlay({
    super.key,
    required this.strokes,
    this.currentStroke,
    this.isDrawing = false,
    this.onStrokeStart,
    this.onStrokeUpdate,
    this.onStrokeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final painter = _AnnotationPainter(
      strokes: strokes,
      currentStroke: currentStroke,
    );

    if (!isDrawing) {
      // Paint strokes but pass all gestures through
      return IgnorePointer(
        child: CustomPaint(
          painter: painter,
          size: Size.infinite,
        ),
      );
    }

    // Drawing mode: intercept pan gestures
    return GestureDetector(
      onPanStart: (details) => onStrokeStart?.call(details.localPosition),
      onPanUpdate: (details) => onStrokeUpdate?.call(details.localPosition),
      onPanEnd: (_) => onStrokeEnd?.call(),
      child: CustomPaint(
        painter: painter,
        size: Size.infinite,
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;

  _AnnotationPainter({required this.strokes, this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
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
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];
        final midX = (p0.x + p1.x) / 2;
        final midY = (p0.y + p1.y) / 2;
        path.quadraticBezierTo(p0.x, p0.y, midX, midY);
      }
      final last = stroke.points.last;
      path.lineTo(last.x, last.y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.strokes.length != strokes.length ||
        oldDelegate.currentStroke != currentStroke;
  }
}
