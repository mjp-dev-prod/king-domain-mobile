import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/debug_log.dart';
import '../../data/api_client.dart';
import '../../data/models/reputation.dart';
import 'auth_provider.dart';

/// One person's review screen for one job (both sides use it).
final reviewProvider = FutureProvider.autoDispose.family<ReviewState, String>((ref, jobId) async {
  final json = await ApiClient.instance.get('/jobs/$jobId/review') as Map<String, dynamic>;
  return ReviewState.fromJson(json);
});

/// The signed-in person's own reputation, as others see it.
final myReputationProvider = FutureProvider.autoDispose<MyReputation>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/users/me/reputation') as Map<String, dynamic>;
  return MyReputation.fromJson(json);
});

final credentialsProvider = FutureProvider.autoDispose<CredentialList>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/users/me/credentials') as Map<String, dynamic>;
  return CredentialList.fromJson(json);
});

class ReviewActions {
  final Ref _ref;
  ReviewActions(this._ref);

  ApiClient get _api => ApiClient.instance;

  void _refresh(String jobId) {
    _ref.invalidate(reviewProvider(jobId));
    _ref.invalidate(myReputationProvider);
  }

  /// Sends (or, while still hidden, edits) the person's review.
  Future<void> submit(String jobId, {required Map<String, dynamic> answers, required String comment, required bool privateAgain}) async {
    await _api.post('/jobs/$jobId/review', body: {'answers': answers, 'comment': comment, 'privateAgain': privateAgain});
    kdLog('review', 'submitted job=$jobId answers=${answers.keys.join(',')}');
    _refresh(jobId);
  }

  Future<void> reply(String jobId, String text) async {
    await _api.post('/jobs/$jobId/review/reply', body: {'text': text});
    _refresh(jobId);
  }

  Future<void> report(String reviewId, {required String reasonCode, String? note}) async {
    await _api.post('/reviews/$reviewId/report', body: {'reasonCode': reasonCode, 'note': ?note});
  }
}

final reviewActionsProvider = Provider<ReviewActions>((ref) => ReviewActions(ref));
