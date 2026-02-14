import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Vertical altitude slider for the pressure-level clouds overlay.
///
/// Displays on the right edge of the map when clouds layer is active.
/// Discrete stops at 14 HRRR pressure levels mapped to flight altitudes.
class CloudAltitudeSlider extends StatefulWidget {
  final int level; // pressure level in hPa
  final ValueChanged<int> onChanged;

  const CloudAltitudeSlider({
    super.key,
    required this.level,
    required this.onChanged,
  });

  @override
  State<CloudAltitudeSlider> createState() => _CloudAltitudeSliderState();
}

class _CloudAltitudeSliderState extends State<CloudAltitudeSlider> {
  static const _levels = [
    (hPa: 1000, ft: 360),
    (hPa: 950, ft: 1640),
    (hPa: 925, ft: 2500),
    (hPa: 900, ft: 3200),
    (hPa: 850, ft: 5000),
    (hPa: 800, ft: 6200),
    (hPa: 700, ft: 10000),
    (hPa: 600, ft: 14000),
    (hPa: 500, ft: 18000),
    (hPa: 400, ft: 24000),
    (hPa: 300, ft: 30000),
    (hPa: 250, ft: 34000),
    (hPa: 200, ft: 39000),
    (hPa: 150, ft: 44000),
  ];

  late double _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexForLevel(widget.level);
  }

  @override
  void didUpdateWidget(covariant CloudAltitudeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _currentIndex = _indexForLevel(widget.level);
    }
  }

  double _indexForLevel(int hPa) {
    final idx = _levels.indexWhere((l) => l.hPa == hPa);
    return idx >= 0 ? idx.toDouble() : 4.0; // default to 850 hPa (index 4)
  }

  static String _formatAltitude(int ft) {
    if (ft >= 18000) {
      return 'FL${ft ~/ 100}';
    }
    if (ft >= 10000) {
      return '${ft ~/ 1000}k';
    }
    return '${(ft / 1000).toStringAsFixed(0)}k';
  }

  @override
  Widget build(BuildContext context) {
    final current = _levels[_currentIndex.round()];

    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current altitude label
          Text(
            _formatAltitude(current.ft),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),

          // Vertical slider (rotated horizontal slider)
          SizedBox(
            height: 220,
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor:
                      AppColors.textMuted.withValues(alpha: 0.3),
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withValues(alpha: 0.2),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  tickMarkShape: const RoundSliderTickMarkShape(
                    tickMarkRadius: 2,
                  ),
                  activeTickMarkColor:
                      AppColors.accent.withValues(alpha: 0.5),
                  inactiveTickMarkColor:
                      AppColors.textMuted.withValues(alpha: 0.3),
                ),
                child: Slider(
                  value: _currentIndex,
                  min: 0,
                  max: (_levels.length - 1).toDouble(),
                  divisions: _levels.length - 1,
                  onChanged: (value) {
                    setState(() {
                      _currentIndex = value;
                    });
                  },
                  onChangeEnd: (value) {
                    final idx = value.round();
                    widget.onChanged(_levels[idx].hPa);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),
          // Cloud icon at bottom
          const Icon(
            Icons.cloud_outlined,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}
