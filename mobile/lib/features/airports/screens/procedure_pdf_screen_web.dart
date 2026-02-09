import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../../core/theme/app_theme.dart';

class PlatformPdfScreen extends StatefulWidget {
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
  State<PlatformPdfScreen> createState() => _PlatformPdfScreenState();
}

class _PlatformPdfScreenState extends State<PlatformPdfScreen> {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: AppColors.surface,
      ),
      body: HtmlElementView(viewType: _viewType),
    );
  }
}
