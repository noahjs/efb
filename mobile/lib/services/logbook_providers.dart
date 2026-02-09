import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/logbook_entry.dart';
import 'api_client.dart';

/// Provider for the logbook entries list, parameterized by search query
final logbookListProvider =
    FutureProvider.family<List<LogbookEntry>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final result =
      await api.getLogbookEntries(query: query.isEmpty ? null : query);
  final items = result['items'] as List<dynamic>;
  return items.map((json) => LogbookEntry.fromJson(json)).toList();
});

/// Provider for a single logbook entry by ID
final logbookDetailProvider =
    FutureProvider.family<LogbookEntry?, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getLogbookEntry(id);
  return LogbookEntry.fromJson(json);
});

/// Provider for logbook summary stats
final logbookSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getLogbookSummary();
});

/// Provider for logbook experience report, parameterized by period string
final logbookExperienceReportProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final api = ref.watch(apiClientProvider);
  return api.getLogbookExperienceReport(period: period);
});

/// Service class for logbook mutations
class LogbookService {
  final ApiClient _api;

  LogbookService(this._api);

  Future<LogbookEntry> createEntry(Map<String, dynamic> data) async {
    final json = await _api.createLogbookEntry(data);
    return LogbookEntry.fromJson(json);
  }

  Future<LogbookEntry> updateEntry(int id, Map<String, dynamic> data) async {
    final json = await _api.updateLogbookEntry(id, data);
    return LogbookEntry.fromJson(json);
  }

  Future<void> deleteEntry(int id) async {
    await _api.deleteLogbookEntry(id);
  }
}

final logbookServiceProvider = Provider<LogbookService>((ref) {
  return LogbookService(ref.watch(apiClientProvider));
});
