import 'package:flutter/material.dart';
import 'map_view_native.dart' if (dart.library.html) 'map_view_web.dart'
    as platform_map;

const String mapboxAccessToken =
    'pk.eyJ1Ijoibm9haGpzIiwiYSI6ImNtbGQzbzF5dTBmMWszZnB4aDgzbDZzczUifQ.yv1FBDKs9T1RllaF7h_WxA';

class EfbMapView extends StatelessWidget {
  final String baseLayer;

  const EfbMapView({super.key, required this.baseLayer});

  @override
  Widget build(BuildContext context) {
    return platform_map.PlatformMapView(baseLayer: baseLayer);
  }
}
