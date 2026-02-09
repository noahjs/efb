import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
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
  String? _localPath;
  bool _loading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _bannerExpanded = false;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
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
        actions: [
          if (_totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16),
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
        ],
      ),
      body: Column(
        children: [
          if (matchedNotams.isNotEmpty)
            _NotamBanner(
              notams: matchedNotams,
              expanded: _bannerExpanded,
              onToggle: () =>
                  setState(() => _bannerExpanded = !_bannerExpanded),
            ),
          Expanded(child: _buildBody()),
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
      enableSwipe: true,
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
