import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/endorsement.dart';
import 'api_client.dart';

/// Provider for the endorsements list, parameterized by search query
final endorsementsListProvider =
    FutureProvider.family<List<Endorsement>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final result =
      await api.getEndorsements(query: query.isEmpty ? null : query);
  final items = result['items'] as List<dynamic>;
  return items.map((json) => Endorsement.fromJson(json)).toList();
});

/// Provider for a single endorsement by ID
final endorsementDetailProvider =
    FutureProvider.family<Endorsement?, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getEndorsement(id);
  return Endorsement.fromJson(json);
});

/// Service class for endorsement mutations
class EndorsementsService {
  final ApiClient _api;

  EndorsementsService(this._api);

  Future<Endorsement> createEndorsement(Map<String, dynamic> data) async {
    final json = await _api.createEndorsement(data);
    return Endorsement.fromJson(json);
  }

  Future<Endorsement> updateEndorsement(
      int id, Map<String, dynamic> data) async {
    final json = await _api.updateEndorsement(id, data);
    return Endorsement.fromJson(json);
  }

  Future<void> deleteEndorsement(int id) async {
    await _api.deleteEndorsement(id);
  }
}

final endorsementsServiceProvider = Provider<EndorsementsService>((ref) {
  return EndorsementsService(ref.watch(apiClientProvider));
});
