import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: uri_does_not_exist
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

Widget buildPdfViewer(Uint8List bytes, int documentId) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final viewType = 'pdf-viewer-$documentId';
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      return html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    },
  );

  return HtmlElementView(viewType: viewType);
}
