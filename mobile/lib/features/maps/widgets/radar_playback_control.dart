import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/map_layer_state_provider.dart';

/// Horizontal playback bar for animated NEXRAD radar loop.
///
/// Shows when the radar layer is active. Auto-cycles through 11 frames
/// (50 minutes of history at 5-minute intervals) and provides a scrubber
/// for manual frame selection.
class RadarPlaybackControl extends ConsumerStatefulWidget {
  const RadarPlaybackControl({super.key});

  @override
  ConsumerState<RadarPlaybackControl> createState() =>
      _RadarPlaybackControlState();
}

class _RadarPlaybackControlState extends ConsumerState<RadarPlaybackControl> {
  static const _frameCount = 11;

  /// Labels for each frame: -60 min ... -6 min, Now (6-min intervals)
  static const _frameLabels = [
    '-60m', '-54m', '-48m', '-42m', '-36m',
    '-30m', '-24m', '-18m', '-12m', '-6m', 'Now',
  ];

  bool _playing = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
    });
    if (_playing) {
      _startLoop();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      final state = ref.read(mapLayerStateProvider).value;
      if (state == null) return;
      final current = state.radarFrameIndex;
      final next = (current + 1) % _frameCount;
      ref.read(mapLayerStateProvider.notifier).setRadarFrame(next);

      // Pause longer on the "Now" frame before looping
      if (next == _frameCount - 1) {
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 1500), () {
          if (_playing && mounted) _startLoop();
        });
      }
    });
  }

  void _scrubTo(int index) {
    ref.read(mapLayerStateProvider.notifier).setRadarFrame(index);
  }

  @override
  Widget build(BuildContext context) {
    final layerState = ref.watch(mapLayerStateProvider).value;
    final frameIndex = layerState?.radarFrameIndex ?? 10;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Play/pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Icon(
              _playing ? Icons.pause : Icons.play_arrow,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),

          // Time scrubber
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor:
                    AppColors.textMuted.withValues(alpha: 0.3),
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withValues(alpha: 0.2),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                ),
                tickMarkShape: const RoundSliderTickMarkShape(
                  tickMarkRadius: 1.5,
                ),
                activeTickMarkColor:
                    AppColors.accent.withValues(alpha: 0.5),
                inactiveTickMarkColor:
                    AppColors.textMuted.withValues(alpha: 0.3),
              ),
              child: Slider(
                value: frameIndex.toDouble(),
                min: 0,
                max: (_frameCount - 1).toDouble(),
                divisions: _frameCount - 1,
                onChanged: (value) {
                  _scrubTo(value.round());
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Time label
          SizedBox(
            width: 40,
            child: Text(
              _frameLabels[frameIndex],
              style: TextStyle(
                color: frameIndex == _frameCount - 1
                    ? AppColors.accent
                    : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
