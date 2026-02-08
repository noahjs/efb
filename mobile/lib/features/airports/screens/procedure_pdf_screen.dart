import 'package:flutter/material.dart';
import 'procedure_pdf_screen_native.dart' if (dart.library.html) 'procedure_pdf_screen_web.dart'
    as platform_pdf;

class ProcedurePdfScreen extends StatelessWidget {
  final String title;
  final String pdfUrl;

  const ProcedurePdfScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  @override
  Widget build(BuildContext context) {
    return platform_pdf.PlatformPdfScreen(title: title, pdfUrl: pdfUrl);
  }
}
