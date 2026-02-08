import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/scratchpad.dart';

class TemplateBackgroundPainter extends CustomPainter {
  final ScratchPadTemplate template;

  TemplateBackgroundPainter(this.template);

  @override
  void paint(Canvas canvas, Size size) {
    switch (template) {
      case ScratchPadTemplate.craft:
        _drawCraft(canvas, size);
        break;
      case ScratchPadTemplate.grid:
        _drawGrid(canvas, size);
        break;
      case ScratchPadTemplate.atis:
        _drawSections(canvas, size,
            ['INFO', 'WIND', 'VIS', 'CEIL', 'TEMP', 'DEW', 'ALTM', 'RMK']);
        break;
      case ScratchPadTemplate.pirep:
        _drawSections(canvas, size,
            ['LOC', 'TIME', 'FL', 'ACFT', 'SKY', 'WX', 'TURB', 'ICE', 'RMK']);
        break;
      case ScratchPadTemplate.takeoff:
        _drawSections(
            canvas, size, ['RWY', 'DEPARTURE', 'INITIAL ALT', 'EMERGENCY', 'ABORT']);
        break;
      case ScratchPadTemplate.landing:
        _drawSections(
            canvas, size, ['APPROACH', 'RWY', 'MINIMUMS', 'MISSED', 'NOTES']);
        break;
      case ScratchPadTemplate.holding:
        _drawSections(
            canvas, size, ['FIX', 'RADIAL', 'LEG', 'DIRECTION', 'EFC', '']);
        break;
      case ScratchPadTemplate.draw:
      case ScratchPadTemplate.type:
        // No background
        break;
    }
  }

  void _drawCraft(Canvas canvas, Size size) {
    final labels = ['C', 'R', 'A', 'F', 'T'];
    final sectionHeight = size.height / labels.length;

    final linePaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;

    for (int i = 0; i < labels.length; i++) {
      final y = i * sectionHeight;

      // Divider line
      if (i > 0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }

      // Section label
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(12, y + 8));
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    const spacing = 32.0;
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawSections(Canvas canvas, Size size, List<String> labels) {
    final sectionHeight = size.height / labels.length;

    final linePaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;

    for (int i = 0; i < labels.length; i++) {
      final y = i * sectionHeight;

      if (i > 0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }

      if (labels[i].isEmpty) continue;

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(12, y + 8));
    }
  }

  @override
  bool shouldRepaint(covariant TemplateBackgroundPainter oldDelegate) {
    return oldDelegate.template != template;
  }
}
