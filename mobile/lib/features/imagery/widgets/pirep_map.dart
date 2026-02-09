import 'pirep_map_native.dart' if (dart.library.html) 'pirep_map_web.dart'
    as platform;

export 'pirep_map_native.dart' if (dart.library.html) 'pirep_map_web.dart';

/// Re-export so pirep_viewer.dart can reference [PirepMap] without
/// knowing which platform file supplies it.
typedef PirepMap = platform.PirepMap;
