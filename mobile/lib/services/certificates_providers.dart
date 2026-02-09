import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/certificate.dart';
import 'api_client.dart';

/// Provider for the certificates list, parameterized by search query
final certificatesListProvider =
    FutureProvider.family<List<Certificate>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final result =
      await api.getCertificates(query: query.isEmpty ? null : query);
  final items = result['items'] as List<dynamic>;
  return items.map((json) => Certificate.fromJson(json)).toList();
});

/// Provider for a single certificate by ID
final certificateDetailProvider =
    FutureProvider.family<Certificate?, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getCertificate(id);
  return Certificate.fromJson(json);
});

/// Service class for certificate mutations
class CertificatesService {
  final ApiClient _api;

  CertificatesService(this._api);

  Future<Certificate> createCertificate(Map<String, dynamic> data) async {
    final json = await _api.createCertificate(data);
    return Certificate.fromJson(json);
  }

  Future<Certificate> updateCertificate(
      int id, Map<String, dynamic> data) async {
    final json = await _api.updateCertificate(id, data);
    return Certificate.fromJson(json);
  }

  Future<void> deleteCertificate(int id) async {
    await _api.deleteCertificate(id);
  }
}

final certificatesServiceProvider = Provider<CertificatesService>((ref) {
  return CertificatesService(ref.watch(apiClientProvider));
});
