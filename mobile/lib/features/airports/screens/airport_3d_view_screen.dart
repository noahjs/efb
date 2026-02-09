import 'package:flutter/material.dart';
import 'airport_3d_view_screen_native.dart'
    if (dart.library.html) 'airport_3d_view_screen_web.dart' as platform_3d;

class Airport3dViewScreen extends StatelessWidget {
  final Map<String, dynamic> airport;

  const Airport3dViewScreen({super.key, required this.airport});

  @override
  Widget build(BuildContext context) {
    return platform_3d.Platform3dViewScreen(airport: airport);
  }
}
