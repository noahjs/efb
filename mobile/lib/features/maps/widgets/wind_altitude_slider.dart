import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Vertical altitude slider for the winds aloft overlay.
///
/// Displays on the right edge of the map when winds aloft is active.
/// Discrete stops at standard aviation altitudes; shows FL notation at/above FL180.
class WindAltitudeSlider extends StatefulWidget {
  final int altitude;
  final ValueChanged<int> onChanged;

  const WindAltitudeSlider({
    super.key,
    required this.altitude,
    required this.onChanged,
  });

  @override
  State<WindAltitudeSlider> createState() => _WindAltitudeSliderState();
}

class _WindAltitudeSliderState extends State<WindAltitudeSlider> {
  static const _altitudes = [
    3000,
    6000,
    9000,
    12000,
    15000,
    18000,
    24000,
    30000,
    39000,
    45000,
  ];

  late double _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _indexForAltitude(widget.altitude);
  }

  @override
  void didUpdateWidget(covariant WindAltitudeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.altitude != widget.altitude) {
      _currentIndex = _indexForAltitude(widget.altitude);
    }
  }

  double _indexForAltitude(int alt) {
    final idx = _altitudes.indexOf(alt);
    return idx >= 0 ? idx.toDouble() : 2.0; // default to 9000 (index 2)
  }

  static String _formatAltitude(int alt) {
    if (alt >= 18000) {
      return 'FL${alt ~/ 100}';
    }
    if (alt >= 10000) {
      return '${alt ~/ 1000}k';
    }
    return '${(alt / 1000).toStringAsFixed(0)}k';
  }

  @override
  Widget build(BuildContext context) {
    final currentAlt = _altitudes[_currentIndex.round()];

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
            _formatAltitude(currentAlt),
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
                  inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.3),
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withValues(alpha: 0.2),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  tickMarkShape: const RoundSliderTickMarkShape(
                    tickMarkRadius: 2,
                  ),
                  activeTickMarkColor: AppColors.accent.withValues(alpha: 0.5),
                  inactiveTickMarkColor:
                      AppColors.textMuted.withValues(alpha: 0.3),
                ),
                child: Slider(
                  value: _currentIndex,
                  min: 0,
                  max: (_altitudes.length - 1).toDouble(),
                  divisions: _altitudes.length - 1,
                  onChanged: (value) {
                    setState(() {
                      _currentIndex = value;
                    });
                  },
                  onChangeEnd: (value) {
                    final idx = value.round();
                    widget.onChanged(_altitudes[idx]);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),
          // Wind icon at bottom
          const Icon(
            Icons.air,
            color: AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}
