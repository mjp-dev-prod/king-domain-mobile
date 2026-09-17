import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../data/models/talent_profile.dart';

/// Real backend now (king-domain-backend's /users/me/profile and
/// /users/me/proof-items — Sprint 2). simulateReviewApproval() is gone:
/// verification is a real human-reviewer action on the admin side
/// (see backend/src/admin/proofReviewRoutes.js) — there is no self-approve
/// path anymore, by design.
class TalentProfileNotifier extends AsyncNotifier<TalentProfile> {
  @override
  Future<TalentProfile> build() => _fetch();

  Future<TalentProfile> _fetch() async {
    final data = await ApiClient.instance.get('/users/me/profile');
    return TalentProfile.fromJson(data['profile'] as Map<String, dynamic>);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> updateProfile({String? headline, String? bio, List<String>? skillCategories}) async {
    final data = await ApiClient.instance.patch(
      '/users/me/profile',
      body: {
        'headline': ?headline,
        'bio': ?bio,
        'skillCategories': ?skillCategories,
      },
    );
    state = AsyncData(TalentProfile.fromJson(data['profile'] as Map<String, dynamic>));
  }

  Future<void> addProofItem({
    required String category,
    required String title,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    await ApiClient.instance.postMultipart(
      '/users/me/proof-items',
      fields: {'category': category, 'title': title},
      fileBytes: fileBytes,
      fileField: 'file',
      fileName: fileName,
    );
    await refresh();
  }

  Future<void> removeProofItem(String id) async {
    await ApiClient.instance.delete('/users/me/proof-items/$id');
    await refresh();
  }
}

final talentProfileProvider =
    AsyncNotifierProvider<TalentProfileNotifier, TalentProfile>(TalentProfileNotifier.new);
