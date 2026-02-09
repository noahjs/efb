import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/notam_matcher.dart';
import '../../../services/airport_providers.dart';

class PlatformPdfScreen extends ConsumerStatefulWidget {
  final String title;
  final String pdfUrl;
  final String? airportId;
  final String? chartCode;

  const PlatformPdfScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    this.airportId,
    this.chartCode,
  });

  @override
  ConsumerState<PlatformPdfScreen> createState() => _PlatformPdfScreenState();
}

class _PlatformPdfScreenState extends ConsumerState<PlatformPdfScreen> {
  late final String _viewType;
  bool _notamDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-view-${DateTime.now().millisecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final embed =
          web.document.createElement('embed') as web.HTMLEmbedElement;
      embed.src = widget.pdfUrl;
      embed.type = 'application/pdf';
      embed.style
        ..width = '100%'
        ..height = '100%'
        ..border = 'none';
      return embed;
    });
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
      ),
      body: Column(
        children: [
          // Banner sits in the layout flow, above the PDF — no z-order issue
          if (hasNotams)
            GestureDetector(
              onTap: () =>
                  setState(() => _notamDrawerOpen = !_notamDrawerOpen),
              child: Container(
                width: double.infinity,
                color: AppColors.error.withValues(alpha: 0.15),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

          // PDF area with dropdown overlay
          Expanded(
            child: _notamDrawerOpen
                ? _NotamDrawer(
                    notams: matchedNotams,
                    onDismiss: () =>
                        setState(() => _notamDrawerOpen = false),
                  )
                : HtmlElementView(viewType: _viewType),
          ),
        ],
      ),
    );
  }
}

class _NotamDrawer extends StatelessWidget {
  final List<Map<String, dynamic>> notams;
  final VoidCallback onDismiss;

  const _NotamDrawer({required this.notams, required this.onDismiss});

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
      return Container(
        color: AppColors.surface,
        child: _NotamListView(notams: notams),
      );
    }

    return DefaultTabController(
      length: types.length + 1,
      child: Container(
        color: AppColors.surface,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
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
      separatorBuilder: (_, _) => const SizedBox(height: 8),
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
