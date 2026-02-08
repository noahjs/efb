import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/flight.dart';
import '../../models/scratchpad.dart';
import '../../services/api_client.dart';
import '../../services/scratchpad_providers.dart';
import 'widgets/drawing_canvas.dart';

class ScratchPadEditorScreen extends ConsumerStatefulWidget {
  final String padId;

  const ScratchPadEditorScreen({super.key, required this.padId});

  @override
  ConsumerState<ScratchPadEditorScreen> createState() =>
      _ScratchPadEditorScreenState();
}

class _ScratchPadEditorScreenState
    extends ConsumerState<ScratchPadEditorScreen> {
  ScratchPad? _pad;
  List<Stroke> _strokes = [];
  Stroke? _currentStroke;
  bool _isEraser = false;
  Color _penColor = Colors.white;
  double _strokeWidth = 2.0;
  bool _loaded = false;
  Map<String, String>? _craftHints;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadPad();
  }

  Future<void> _loadPad() async {
    final storage = ref.read(scratchPadStorageProvider);
    final pad = await storage.load(widget.padId);
    if (pad != null && mounted) {
      setState(() {
        _pad = pad;
        _strokes = List.from(pad.strokes);
        _craftHints = pad.craftHints;
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    if (_pad == null) return;
    final updated = _pad!.copyWith(
      strokes: _strokes,
      craftHints: _craftHints,
      updatedAt: DateTime.now(),
    );
    _pad = updated;
    await ref.read(scratchPadListProvider.notifier).save(updated);
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes = _strokes.sublist(0, _strokes.length - 1);
    });
    _save();
  }

  void _clear() async {
    if (_strokes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear All?'),
        content: const Text('This will remove all drawings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _strokes = [];
        _craftHints = null;
      });
      if (_pad != null) {
        final updated = _pad!.copyWith(
          strokes: [],
          clearCraftHints: true,
          updatedAt: DateTime.now(),
        );
        _pad = updated;
        await ref.read(scratchPadListProvider.notifier).save(updated);
      }
    }
  }

  Future<void> _syncWithFlight() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    try {
      final api = ref.read(apiClientProvider);

      // Fetch all flights
      final result = await api.getFlights();
      final items = result['items'] as List<dynamic>;
      final flights = items.map((json) => Flight.fromJson(json)).toList();

      if (flights.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No flights found'),
              backgroundColor: AppColors.surfaceLight,
            ),
          );
        }
        return;
      }

      // Find the flight with the closest ETD to now
      final now = DateTime.now();
      Flight? closest;
      Duration? closestDiff;

      for (final flight in flights) {
        if (flight.departureIdentifier == null ||
            flight.destinationIdentifier == null) {
          continue;
        }

        Duration diff;
        if (flight.etd != null && flight.etd!.isNotEmpty) {
          try {
            final etd = DateTime.parse(flight.etd!);
            diff = (etd.difference(now)).abs();
          } catch (_) {
            // If ETD isn't parseable, use a large diff but still consider it
            diff = const Duration(days: 365);
          }
        } else {
          // No ETD — use updatedAt/createdAt as a fallback proxy
          diff = const Duration(days: 365);
        }

        if (closestDiff == null || diff < closestDiff) {
          closest = flight;
          closestDiff = diff;
        }
      }

      if (closest == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No flights with departure/destination found'),
              backgroundColor: AppColors.surfaceLight,
            ),
          );
        }
        return;
      }

      // Build CRAFT hints from matched flight
      final hints = <String, String>{};

      // C - Clearance: destination
      hints['C'] = 'Cleared to ${closest.destinationIdentifier}';

      // R - Route
      if (closest.routeString != null && closest.routeString!.isNotEmpty) {
        hints['R'] = closest.routeString!;
      } else {
        hints['R'] = 'Direct ${closest.destinationIdentifier}';
      }

      // A - Altitude
      if (closest.cruiseAltitude != null) {
        final alt = closest.cruiseAltitude!;
        final altStr = alt >= 18000
            ? 'FL${alt ~/ 100}'
            : '${alt.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}\'';
        hints['A'] = '_____ expect $altStr in ___ min';
      }

      // F - Frequency: departure freq, then ARTCC center, else blank
      if (closest.departureIdentifier != null) {
        try {
          final freqs = await api.getFrequencies(closest.departureIdentifier!);
          String? depFreq;
          for (final f in freqs) {
            final type = (f['type'] as String?)?.toUpperCase().trim() ?? '';
            final freq = f['frequency'] as String?;
            if (freq == null) continue;
            if (type == 'DEP') {
              depFreq = freq;
              break;
            }
          }

          if (depFreq != null) {
            hints['F'] = '${closest.departureIdentifier} Departure $depFreq';
          } else {
            final airport =
                await api.getAirport(closest.departureIdentifier!);
            final artccName = airport?['artcc_name'] as String?;
            if (artccName != null && artccName.isNotEmpty) {
              hints['F'] = '$artccName Center';
            }
          }
        } catch (_) {}
      }


      if (mounted) {
        setState(() => _craftHints = hints);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${closest.departureIdentifier} → ${closest.destinationIdentifier}'),
            backgroundColor: AppColors.surfaceLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _onStrokeStart(Offset position) {
    setState(() {
      _currentStroke = Stroke(
        points: [
          StrokePoint(x: position.dx, y: position.dy),
        ],
        colorValue: _isEraser ? 0x00000000 : _penColor.toARGB32(),
        strokeWidth: _isEraser ? 20.0 : _strokeWidth,
        isEraser: _isEraser,
      );
    });
  }

  void _onStrokeUpdate(Offset position) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke = Stroke(
        points: [
          ..._currentStroke!.points,
          StrokePoint(x: position.dx, y: position.dy),
        ],
        colorValue: _currentStroke!.colorValue,
        strokeWidth: _currentStroke!.strokeWidth,
        isEraser: _currentStroke!.isEraser,
      );
    });
  }

  void _onStrokeEnd() {
    if (_currentStroke != null && _currentStroke!.points.length >= 2) {
      setState(() {
        _strokes = [..._strokes, _currentStroke!];
        _currentStroke = null;
      });
      _save();
    } else {
      setState(() => _currentStroke = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isCraft = _pad?.template == ScratchPadTemplate.craft;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 48,
        title: Row(
          children: [
            // Close button
            _ToolbarButton(
              label: 'Close',
              onTap: () {
                _save();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: 8),

            // Pen tool
            _ToolbarToggle(
              icon: Icons.edit,
              isActive: !_isEraser,
              onTap: () => setState(() => _isEraser = false),
            ),
            const SizedBox(width: 4),

            // Color/width indicator
            GestureDetector(
              onTap: () => _showStrokeSettings(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _penColor,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: AppColors.divider),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _strokeWidth.round().toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Sync button (CRAFT only)
            if (isCraft)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: _syncing ? null : _syncWithFlight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _craftHints != null
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Icon(
                            Icons.sync,
                            size: 18,
                            color: _craftHints != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                  ),
                ),
              ),

            // Eraser
            _ToolbarToggle(
              icon: Icons.auto_fix_high,
              isActive: _isEraser,
              onTap: () => setState(() => _isEraser = true),
            ),
            const SizedBox(width: 4),

            // Clear
            _ToolbarButton(
              label: 'Clear',
              onTap: _clear,
            ),
            const SizedBox(width: 4),

            // Undo
            IconButton(
              icon: const Icon(Icons.undo, size: 20),
              onPressed: _strokes.isEmpty ? null : _undo,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              color: AppColors.textPrimary,
              disabledColor: AppColors.textMuted,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date/time bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _pad != null
                    ? DateFormat('M/d/yy, h:mm a').format(_pad!.createdAt)
                    : '',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),

          // Drawing area
          Expanded(
            child: DrawingCanvas(
              strokes: _strokes,
              currentStroke: _currentStroke,
              template: _pad?.template ?? ScratchPadTemplate.draw,
              craftHints: _craftHints,
              onStrokeStart: _onStrokeStart,
              onStrokeUpdate: _onStrokeUpdate,
              onStrokeEnd: _onStrokeEnd,
            ),
          ),
        ],
      ),
    );
  }

  void _showStrokeSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _StrokeSettingsSheet(
        currentColor: _penColor,
        currentWidth: _strokeWidth,
        onColorChanged: (c) => setState(() => _penColor = c),
        onWidthChanged: (w) => setState(() => _strokeWidth = w),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ToolbarToggle extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarToggle({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StrokeSettingsSheet extends StatefulWidget {
  final Color currentColor;
  final double currentWidth;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;

  const _StrokeSettingsSheet({
    required this.currentColor,
    required this.currentWidth,
    required this.onColorChanged,
    required this.onWidthChanged,
  });

  @override
  State<_StrokeSettingsSheet> createState() => _StrokeSettingsSheetState();
}

class _StrokeSettingsSheetState extends State<_StrokeSettingsSheet> {
  late Color _color;
  late double _width;

  static const _colors = [
    Colors.white,
    Color(0xFF4A90D9), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFFC107), // Yellow
    Color(0xFFFF5252), // Red
    Color(0xFFFF00FF), // Magenta
  ];

  @override
  void initState() {
    super.initState();
    _color = widget.currentColor;
    _width = widget.currentWidth;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pen Color',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _colors.map((c) {
              final isSelected = c.toARGB32() == _color.toARGB32();
              return GestureDetector(
                onTap: () {
                  setState(() => _color = c);
                  widget.onColorChanged(c);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: AppColors.accent, width: 3)
                        : Border.all(color: AppColors.divider, width: 1),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Stroke Width',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Slider(
            value: _width,
            min: 1,
            max: 8,
            divisions: 7,
            label: _width.round().toString(),
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceLight,
            onChanged: (v) {
              setState(() => _width = v);
              widget.onWidthChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
