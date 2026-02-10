import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

Widget buildPdfViewer(Uint8List bytes, int documentId) {
  final path = '${Directory.systemTemp.path}/efb_doc_$documentId.pdf';
  final file = File(path);
  file.writeAsBytesSync(bytes);

  return PDFView(
    filePath: path,
    enableSwipe: true,
    swipeHorizontal: false,
    autoSpacing: true,
    pageFling: true,
    nightMode: true,
  );
}
