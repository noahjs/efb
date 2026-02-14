import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

/// Configuration for a time-based playback layer.
class TimePlaybackConfig {
  /// Number of frames in the loop.
  final int frameCount;

  /// Minute offsets from now for each frame (oldest to newest).
  /// Last entry should be 0 for "current".
  final List<int> minuteOffsets;

  /// Interval between frame advances during playback.
  final Duration playInterval;

  /// Extra pause on the final frame before looping.
  final Duration endPause;

  const TimePlaybackConfig({
    required this.frameCount,
    required this.minuteOffsets,
    this.playInterval = const Duration(milliseconds: 750),
    this.endPause = const Duration(milliseconds: 1500),
  });

  /// Standard NEXRAD radar: 11 frames, 6-minute intervals, 60 min history.
  static const radar = TimePlaybackConfig(
    frameCount: 11,
    minuteOffsets: [60, 54, 48, 42, 36, 30, 24, 18, 12, 6, 0],
  );
}

/// Reusable playback control for any time-frame-based map layer.
///
/// Displays a prominent local-time label above a play/pause button and
/// scrubber slider, similar to ForeFlight's radar playback bar.
class TimePlaybackControl extends StatefulWidget {
  final TimePlaybackConfig config;
  final int currentIndex;
  final ValueChanged<int> onFrameChanged;

  const TimePlaybackControl({
    super.key,
    required this.config,
    required this.currentIndex,
    required this.onFrameChanged,
  });

  @override
  State<TimePlaybackControl> createState() => _TimePlaybackControlState();
}

class _TimePlaybackControlState extends State<TimePlaybackControl> {
  bool _playing = false;
  Timer? _timer;

  static final _timeFmt = DateFormat('h:mm a');
  static final _dateFmt = DateFormat('MMM d');

  TimePlaybackConfig get _config => widget.config;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int frameIndex) {
    final now = DateTime.now();
    final t = now.subtract(Duration(minutes: _config.minuteOffsets[frameIndex]));
    final time = _timeFmt.format(t).toUpperCase();
    final date = _dateFmt.format(t).toUpperCase();
    return '$time  -  $date';
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing) {
      _startLoop();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(_config.playInterval, (_) {
      final next = (widget.currentIndex + 1) % _config.frameCount;
      widget.onFrameChanged(next);

      // Pause longer on the last frame before looping
      if (next == _config.frameCount - 1) {
        _timer?.cancel();
        _timer = Timer(_config.endPause, () {
          if (_playing && mounted) _startLoop();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.currentIndex;
    final lastFrame = _config.frameCount - 1;

    return Container(
      margin: const EdgeInsets.only(left: 52, right: 8),
      padding: const EdgeInsets.only(left: 4, right: 8, top: 5, bottom: 0),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time label
          Text(
            _formatTime(index),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),

          // Play button + slider
          Row(
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _togglePlay,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: Colors.white38,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    tickMarkShape: const RoundSliderTickMarkShape(
                      tickMarkRadius: 1.5,
                    ),
                    activeTickMarkColor: Colors.white24,
                    inactiveTickMarkColor: Colors.white12,
                  ),
                  child: Slider(
                    value: index.toDouble(),
                    min: 0,
                    max: lastFrame.toDouble(),
                    divisions: lastFrame,
                    onChanged: (value) {
                      widget.onFrameChanged(value.round());
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
