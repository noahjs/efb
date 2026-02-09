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
          if (matchedNotams.isNotEmpty)
            _NotamBanner(
              notams: matchedNotams,
              onTap: () => _showNotamSheet(context, matchedNotams),
            ),
          Expanded(child: HtmlElementView(viewType: _viewType)),
        ],
      ),
    );
  }
}

class _NotamBanner extends StatelessWidget {
  final List<Map<String, dynamic>> notams;
  final bool expanded;
  final VoidCallback onToggle;

  const _NotamBanner({
    required this.notams,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          color: AppColors.error.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text(
                    '${notams.length} NOTAM${notams.length == 1 ? '' : 's'} affecting this procedure',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.error,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                for (int i = 0; i < notams.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _NotamSummary(notam: notams[i]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotamSummary extends StatelessWidget {
  final Map<String, dynamic> notam;

  const _NotamSummary({required this.notam});

  @override
  Widget build(BuildContext context) {
    final id = notam['id'] as String? ?? '';
    final text = notam['text'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTAM $id',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
