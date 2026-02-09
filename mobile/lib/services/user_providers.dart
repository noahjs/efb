import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getProfile();
  return UserProfile.fromJson(json);
});

class UserProfileService {
  final ApiClient _api;

  UserProfileService(this._api);

  Future<UserProfile> updateProfile(Map<String, dynamic> data) async {
    final json = await _api.updateUserProfile(data);
    return UserProfile.fromJson(json);
  }
}

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(ref.watch(apiClientProvider));
});
