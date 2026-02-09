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
              onTap: () => _showNotamSheet(context, matchedNotams),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  void _showNotamSheet(
      BuildContext context, List<Map<String, dynamic>> notams) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    '${notams.length} NOTAM${notams.length == 1 ? '' : 's'} affecting this procedure',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: notams.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final notam = notams[index];
                  final id = notam['id'] as String? ?? '';
                  final type = notam['type'] as String? ?? '';
                  final text = notam['text'] as String? ?? '';
                  final fullText = notam['fullText'] as String? ?? text;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.divider, width: 0.5),
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
                                  color: AppColors.error
                                      .withValues(alpha: 0.2),
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
                },
              ),
            ),
          ],
        ),
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
  final VoidCallback onTap;

  const _NotamBanner({
    required this.notams,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: AppColors.error.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${notams.length} NOTAM${notams.length == 1 ? '' : 's'} affecting this procedure',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: AppColors.error),
          ],
        ),
      ),
    );
  }
}
