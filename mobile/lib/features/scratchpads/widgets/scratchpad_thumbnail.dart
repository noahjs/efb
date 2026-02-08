import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/theme/app_theme.dart';
import '../../../models/scratchpad.dart';

class ScratchPadThumbnail extends StatelessWidget {
  final ScratchPad pad;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool editMode;

  const ScratchPadThumbnail({
    super.key,
    required this.pad,
    required this.onTap,
    this.onDelete,
    this.editMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Column(
              children: [
                // Preview area
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                    child: CustomPaint(
                      painter: _ThumbnailPainter(pad),
                      size: Size.infinite,
                    ),
                  ),
                ),
                // Date footer
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('M/d/yy').format(pad.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        DateFormat('h:mma').format(pad.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (editMode && onDelete != null)
            Positioned(
              top: -4,
              left: -4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  final ScratchPad pad;

  _ThumbnailPainter(this.pad);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw template background labels
    if (pad.template == ScratchPadTemplate.craft) {
      _drawCraftBackground(canvas, size);
    } else if (pad.template == ScratchPadTemplate.grid) {
      _drawGridBackground(canvas, size);
    } else if (_isStructuredTemplate(pad.template)) {
      _drawStructuredBackground(canvas, size);
    }

    // Draw strokes scaled to thumbnail
    if (pad.strokes.isEmpty) return;

    // Find bounds of all strokes to determine scale
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final stroke in pad.strokes) {
      for (final point in stroke.points) {
        if (point.x < minX) minX = point.x;
        if (point.y < minY) minY = point.y;
        if (point.x > maxX) maxX = point.x;
        if (point.y > maxY) maxY = point.y;
      }
    }

    // Use a fixed reference size for consistent scaling
    const refWidth = 400.0;
    const refHeight = 700.0;
    final scaleX = size.width / refWidth;
    final scaleY = size.height / refHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    for (final stroke in pad.strokes) {
      if (stroke.isEraser || stroke.points.length < 2) continue;

      final paint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.strokeWidth * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(
        stroke.points[0].x * scaleX,
        stroke.points[0].y * scaleY,
      );
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(
          stroke.points[i].x * scaleX,
          stroke.points[i].y * scaleY,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawCraftBackground(Canvas canvas, Size size) {
    final labels = ['C', 'R', 'A', 'F', 'T'];
    final sectionHeight = size.height / labels.length;
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    final linePaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 0.5;

    for (int i = 0; i < labels.length; i++) {
      final y = i * sectionHeight;

      // Section divider line
      if (i > 0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }

      // Label
      labelPaint.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(canvas, Offset(4, y + 2));
    }
  }

  void _drawGridBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    const spacing = 12.0;
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  bool _isStructuredTemplate(ScratchPadTemplate template) {
    return template == ScratchPadTemplate.atis ||
        template == ScratchPadTemplate.pirep ||
        template == ScratchPadTemplate.takeoff ||
        template == ScratchPadTemplate.landing ||
        template == ScratchPadTemplate.holding;
  }

  void _drawStructuredBackground(Canvas canvas, Size size) {
    final labels = _getTemplateLabels(pad.template);
    final sectionHeight = size.height / labels.length;
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    final linePaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 0.5;

    for (int i = 0; i < labels.length; i++) {
      final y = i * sectionHeight;
      if (i > 0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
      labelPaint.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.6),
          fontSize: 6,
          fontWeight: FontWeight.w600,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(canvas, Offset(3, y + 2));
    }
  }

  List<String> _getTemplateLabels(ScratchPadTemplate template) {
    switch (template) {
      case ScratchPadTemplate.atis:
        return ['INFO', 'WIND', 'VIS', 'CEIL', 'TEMP', 'ALTM', 'RMK'];
      case ScratchPadTemplate.pirep:
        return ['LOC', 'TIME', 'FL', 'ACFT', 'SKY', 'WX', 'TURB', 'ICE'];
      case ScratchPadTemplate.takeoff:
        return ['RWY', 'DEP', 'ALT', 'EMER', 'ABORT'];
      case ScratchPadTemplate.landing:
        return ['APR', 'RWY', 'MINS', 'MISS', 'NOTES'];
      case ScratchPadTemplate.holding:
        return ['FIX', 'RAD', 'LEG', 'DIR', 'EFC', 'DIAG'];
      default:
        return [];
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) {
    return oldDelegate.pad.strokes.length != pad.strokes.length ||
        oldDelegate.pad.updatedAt != pad.updatedAt;
  }
}

class NewScratchPadCard extends StatelessWidget {
  final VoidCallback onTap;

  const NewScratchPadCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 40, color: AppColors.textSecondary),
            SizedBox(height: 8),
            Text(
              'NEW',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'SCRATCHPAD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
