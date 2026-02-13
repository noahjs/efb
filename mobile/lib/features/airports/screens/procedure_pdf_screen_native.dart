import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/notam_matcher.dart';
import '../../../models/scratchpad.dart';
import '../../../services/airport_providers.dart';
import '../../../services/plate_annotation_storage.dart';
import '../widgets/plate_annotation_overlay.dart';

class PlatformPdfScreen extends ConsumerStatefulWidget {
  final String title;
  final String pdfUrl;
  final String? airportId;
  final String? chartCode;
  final int? procedureId;

  const PlatformPdfScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    this.airportId,
    this.chartCode,
    this.procedureId,
  });

  @override
  ConsumerState<PlatformPdfScreen> createState() => _PlatformPdfScreenState();
}

class _PlatformPdfScreenState extends ConsumerState<PlatformPdfScreen> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _notamDrawerOpen = false;

  // Annotation state
  bool _isAnnotating = false;
  List<Stroke> _strokes = [];
  Stroke? _currentStroke;
  int _penColor = 0xFFFF3B30; // red default for plate markup
  double _strokeWidth = 3.0;
  bool _isEraser = false;

  bool get _canAnnotate =>
      widget.airportId != null && widget.procedureId != null;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
    _loadAnnotations();
  }

  Future<void> _loadAnnotations() async {
    if (!_canAnnotate) return;
    final strokes = await PlateAnnotationStorage.instance
        .load(widget.airportId!, widget.procedureId!);
    if (mounted && strokes.isNotEmpty) {
      setState(() => _strokes = strokes);
    }
  }

  Future<void> _saveAnnotations() async {
    if (!_canAnnotate) return;
    await PlateAnnotationStorage.instance
        .save(widget.airportId!, widget.procedureId!, _strokes);
  }

  Future<void> _downloadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        setState(() {
          _error = 'Failed to load PDF (HTTP ${response.statusCode})';
          _loading = false;
        });
        return;
      }

      final dir = await getTemporaryDirectory();
      final fileName = widget.pdfUrl.split('/').last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        _localPath = file.path;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load PDF: $e';
        _loading = false;
      });
    }
  }

  void _onStrokeStart(Offset position) {
    setState(() {
      _currentStroke = Stroke(
        points: [StrokePoint(x: position.dx, y: position.dy)],
        colorValue: _isEraser ? 0x00000000 : _penColor,
        strokeWidth: _isEraser ? _strokeWidth * 3 : _strokeWidth,
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
      _saveAnnotations();
    } else {
      setState(() => _currentStroke = null);
    }
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes = _strokes.sublist(0, _strokes.length - 1);
    });
    _saveAnnotations();
  }

  void _clearAll() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes = []);
    _saveAnnotations();
  }

  void _showColorPicker() {
    final colors = [
      0xFFFF3B30, // red
      0xFFFF9500, // orange
      0xFFFFCC00, // yellow
      0xFF34C759, // green
      0xFF007AFF, // blue
      0xFFFFFFFF, // white
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pen Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: colors.map((c) {
                final isSelected = c == _penColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _penColor = c;
                      _isEraser = false;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected ? AppColors.accent : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Stroke Width',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Slider(
              value: _strokeWidth,
              min: 1.0,
              max: 8.0,
              divisions: 7,
              activeColor: AppColors.accent,
              label: _strokeWidth.round().toString(),
              onChanged: (val) => setState(() => _strokeWidth = val),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> matchedNotams = [];
    if (widget.airportId != null && widget.chartCode != null) {
      final notamsData = ref.watch(notamsProvider(widget.airportId!));
      final data = notamsData.whenOrNull(data: (d) => d);
      if (data != null && data['notams'] != null) {
        matchedNotams = NotamProcedureMatcher.match(
          chartName: widget.title,
          chartCode: widget.chartCode!,
          notams: data['notams'] as List<dynamic>,
        );
      }
    }

    final hasNotams = matchedNotams.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: AppColors.surface,
        actions: [
          if (_totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          // Annotation toolbar
          if (_canAnnotate) ...[
            IconButton(
              icon: Icon(
                Icons.edit,
                size: 20,
                color: _isAnnotating ? AppColors.accent : Colors.white70,
              ),
              onPressed: () => setState(() {
                _isAnnotating = !_isAnnotating;
                if (!_isAnnotating) _isEraser = false;
              }),
              tooltip: _isAnnotating ? 'Exit drawing' : 'Draw on plate',
            ),
            if (_isAnnotating) ...[
              IconButton(
                icon: Icon(
                  Icons.auto_fix_high,
                  size: 20,
                  color: _isEraser ? AppColors.accent : Colors.white70,
                ),
                onPressed: () => setState(() => _isEraser = !_isEraser),
                tooltip: 'Eraser',
              ),
              IconButton(
                icon: const Icon(Icons.palette, size: 20, color: Colors.white70),
                onPressed: _showColorPicker,
                tooltip: 'Color & width',
              ),
              IconButton(
                icon: Icon(
                  Icons.undo,
                  size: 20,
                  color: _strokes.isEmpty
                      ? Colors.white24
                      : Colors.white70,
                ),
                onPressed: _strokes.isEmpty ? null : _undo,
                tooltip: 'Undo',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: _strokes.isEmpty
                      ? Colors.white24
                      : Colors.white70,
                ),
                onPressed: _strokes.isEmpty ? null : _clearAll,
                tooltip: 'Clear all',
              ),
            ],
          ],
        ],
      ),
      body: Stack(
        children: [
          // PDF fills entire body
          Positioned.fill(
            child: _isAnnotating
                ? IgnorePointer(child: _buildBody())
                : _buildBody(),
          ),

          // Annotation overlay (always present to show strokes)
          if (_canAnnotate && (_strokes.isNotEmpty || _isAnnotating))
            Positioned.fill(
              child: PlateAnnotationOverlay(
                strokes: _strokes,
                currentStroke: _currentStroke,
                isDrawing: _isAnnotating,
                onStrokeStart: _onStrokeStart,
                onStrokeUpdate: _onStrokeUpdate,
                onStrokeEnd: _onStrokeEnd,
              ),
            ),

          // Banner + dropdown overlay
          if (hasNotams)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: _notamDrawerOpen ? 0 : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Banner bar
                  GestureDetector(
                    onTap: () => setState(
                        () => _notamDrawerOpen = !_notamDrawerOpen),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.error.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${matchedNotams.length} NOTAM${matchedNotams.length == 1 ? '' : 's'} affecting this procedure',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: _notamDrawerOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.expand_more,
                                size: 18, color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dropdown drawer
                  if (_notamDrawerOpen)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          color: AppColors.scrim,
                          child: Column(
                            children: [
                              Flexible(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        MediaQuery.of(context).size.height *
                                            0.6,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(12)),
                                  ),
                                  child: _NotamList(notams: matchedNotams),
                                ),
                              ),
                              // Scrim — tap to dismiss
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _notamDrawerOpen = false),
                                  behavior: HitTestBehavior.opaque,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading procedure...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _downloadPdf();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: !_isAnnotating,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      nightMode: true,
      onRender: (pages) {
        setState(() {
          _totalPages = pages ?? 0;
        });
      },
      onViewCreated: (controller) {},
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
        });
      },
      onError: (error) {
        setState(() {
          _error = 'PDF render error: $error';
        });
      },
    );
  }
}

class _NotamList extends StatelessWidget {
  final List<Map<String, dynamic>> notams;

  const _NotamList({required this.notams});

  @override
  Widget build(BuildContext context) {
    // Collect unique types in order of appearance
    final types = <String>[];
    for (final n in notams) {
      final t = (n['type'] as String?) ?? '';
      if (t.isNotEmpty && !types.contains(t)) types.add(t);
    }

    // If only one type (or none), no tabs needed
    if (types.length <= 1) {
      return _NotamListView(notams: notams);
    }

    return DefaultTabController(
      length: types.length + 1,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              const Tab(text: 'All'),
              for (final t in types) Tab(text: t),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _NotamListView(notams: notams),
                for (final t in types)
                  _NotamListView(
                    notams: notams
                        .where((n) => (n['type'] as String?) == t)
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotamListView extends StatelessWidget {
  final List<Map<String, dynamic>> notams;

  const _NotamListView({required this.notams});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: notams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildCard(notams[index]),
    );
  }

  static Widget _buildCard(Map<String, dynamic> notam) {
    final id = notam['id'] as String? ?? '';
    final type = notam['type'] as String? ?? '';
    final text = notam['text'] as String? ?? '';
    final fullText = notam['fullText'] as String? ?? text;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (type.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
              Text(
                'NOTAM $id',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            fullText,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
