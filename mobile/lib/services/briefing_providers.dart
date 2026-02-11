import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/briefing.dart';
import 'api_client.dart';

final briefingProvider =
    FutureProvider.family<Briefing, int>((ref, flightId) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getFlightBriefing(flightId);
  return Briefing.fromJson(json);
});
