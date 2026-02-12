import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/briefing.dart';
import 'api_client.dart';

/// Key for briefing provider — includes flight ID and whether to regenerate.
class BriefingRequest {
  final int flightId;
  final bool regenerate;

  const BriefingRequest(this.flightId, {this.regenerate = false});

  @override
  bool operator ==(Object other) =>
      other is BriefingRequest &&
      other.flightId == flightId &&
      other.regenerate == regenerate;

  @override
  int get hashCode => Object.hash(flightId, regenerate);
}

final briefingProvider =
    FutureProvider.family<Briefing, BriefingRequest>((ref, request) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getFlightBriefing(
    request.flightId,
    regenerate: request.regenerate,
  );
  return Briefing.fromJson(json);
});
