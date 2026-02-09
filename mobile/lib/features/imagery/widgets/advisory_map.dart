import 'advisory_map_native.dart'
    if (dart.library.html) 'advisory_map_web.dart' as platform;

export 'advisory_map_native.dart'
    if (dart.library.html) 'advisory_map_web.dart';

/// Re-export so advisory_viewer.dart can reference [AdvisoryMap] without
/// knowing which platform file supplies it.
typedef AdvisoryMap = platform.AdvisoryMap;
