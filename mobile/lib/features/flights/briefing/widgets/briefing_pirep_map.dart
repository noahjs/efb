import 'briefing_pirep_map_native.dart'
    if (dart.library.html) 'briefing_pirep_map_web.dart' as platform;

export 'briefing_pirep_map_native.dart'
    if (dart.library.html) 'briefing_pirep_map_web.dart';

typedef BriefingPirepMap = platform.BriefingPirepMap;
