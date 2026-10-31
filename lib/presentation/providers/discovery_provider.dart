import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../data/models/discovery.dart';
import '../../data/models/job.dart';
import 'auth_provider.dart';
import 'jobs_provider.dart';

String _qs(Map<String, String> q) => q.isEmpty ? '' : '?${q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

// ── The feed (talent) ────────────────────────────────────

final feedFiltersProvider = StateProvider<FeedFilters>((ref) => const FeedFilters());

class FeedState {
  final List<Job> jobs;
  final String? nextCursor;
  final bool loadingMore;
  final String? moreError;
  const FeedState({required this.jobs, required this.nextCursor, this.loadingMore = false, this.moreError});
  FeedState copyWith({List<Job>? jobs, String? nextCursor, bool? loadingMore, Object? moreError = _keep}) => FeedState(
    jobs: jobs ?? this.jobs,
    nextCursor: nextCursor ?? this.nextCursor,
    loadingMore: loadingMore ?? this.loadingMore,
    moreError: identical(moreError, _keep) ? this.moreError : moreError as String?,
  );
  static const _keep = Object();
}

/// The server-filtered, paged job feed. Rebuilds when the filters change; `loadMore` follows the cursor.
class FeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    ref.watch(authProvider.select((s) => s.user?.id));
    final filters = ref.watch(feedFiltersProvider);
    return _page(filters, null, const []);
  }

  Future<FeedState> _page(FeedFilters filters, String? cursor, List<Job> before) async {
    final data = await ApiClient.instance.get('/jobs${_qs(filters.toQuery(cursor: cursor))}') as Map<String, dynamic>;
    final jobs = [for (final j in data['jobs'] as List) Job.fromJson(j as Map<String, dynamic>)];
    return FeedState(jobs: [...before, ...jobs], nextCursor: data['nextCursor'] as String?);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.nextCursor == null || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, moreError: null));
    try {
      final next = await _page(ref.read(feedFiltersProvider), current.nextCursor, current.jobs);
      state = AsyncData(next);
    } on ApiException catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false, moreError: e.message));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(FeedNotifier.new);

final jobDetailProvider = FutureProvider.family<JobDetailData, String>((ref, id) async {
  final data = await ApiClient.instance.get('/jobs/$id') as Map<String, dynamic>;
  return JobDetailData.fromJson(data);
});

// ── Saved searches, invitations, shortlist asks (talent) ──

final savedSearchesProvider = FutureProvider<List<SavedSearch>>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final data = await ApiClient.instance.get('/users/me/saved-searches') as Map<String, dynamic>;
  return [for (final s in data['searches'] as List) SavedSearch.fromJson(s as Map<String, dynamic>)];
});

final invitationsProvider = FutureProvider<List<InvitationItem>>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final data = await ApiClient.instance.get('/users/me/invitations') as Map<String, dynamic>;
  return [for (final i in data['invitations'] as List) InvitationItem.fromJson(i as Map<String, dynamic>)];
});

final shortlistAsksProvider = FutureProvider<List<ShortlistAsk>>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final data = await ApiClient.instance.get('/users/me/shortlist-asks') as Map<String, dynamic>;
  return [for (final a in data['asks'] as List) ShortlistAsk.fromJson(a as Map<String, dynamic>)];
});

// ── The post-a-job form (client) ─────────────────────────

/// The brief fields for a skill and type, from the server so the form always matches what it will accept.
final briefSpecProvider = FutureProvider.family<BriefSpec, String>((ref, key) async {
  final parts = key.split('|');
  final data = await ApiClient.instance.get('/briefs/spec?skill=${parts[0]}&type=${parts[1]}') as Map<String, dynamic>;
  return BriefSpec.fromJson(data['spec'] as Map<String, dynamic>);
});

// ── Browse talents (client) ──────────────────────────────

final talentFiltersProvider = StateProvider<TalentFilters>((ref) => const TalentFilters());

class TalentsState {
  final List<TalentCard> talents;
  final String? nextCursor;
  final bool loadingMore;
  const TalentsState({required this.talents, required this.nextCursor, this.loadingMore = false});
}

class TalentsNotifier extends AsyncNotifier<TalentsState> {
  @override
  Future<TalentsState> build() async {
    ref.watch(authProvider.select((s) => s.user?.id));
    return _page(ref.watch(talentFiltersProvider), null, const []);
  }

  Future<TalentsState> _page(TalentFilters f, String? cursor, List<TalentCard> before) async {
    final data = await ApiClient.instance.get('/talents${_qs(f.toQuery(cursor: cursor))}') as Map<String, dynamic>;
    return TalentsState(talents: [...before, for (final t in data['talents'] as List) TalentCard.fromJson(t as Map<String, dynamic>)], nextCursor: data['nextCursor'] as String?);
  }

  Future<void> loadMore() async {
    final c = state.valueOrNull;
    if (c == null || c.nextCursor == null || c.loadingMore) return;
    state = AsyncData(TalentsState(talents: c.talents, nextCursor: c.nextCursor, loadingMore: true));
    try {
      state = AsyncData(await _page(ref.read(talentFiltersProvider), c.nextCursor, c.talents));
    } on ApiException {
      state = AsyncData(TalentsState(talents: c.talents, nextCursor: c.nextCursor));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final talentsProvider = AsyncNotifierProvider<TalentsNotifier, TalentsState>(TalentsNotifier.new);

final talentProfileViewProvider = FutureProvider.family<TalentProfileView, String>((ref, id) async {
  final data = await ApiClient.instance.get('/talents/$id') as Map<String, dynamic>;
  return TalentProfileView.fromJson(data);
});

final savedTalentsProvider = FutureProvider<List<TalentCard>>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final data = await ApiClient.instance.get('/users/me/saved-talents') as Map<String, dynamic>;
  return [for (final t in data['talents'] as List) TalentCard.fromJson(t as Map<String, dynamic>)];
});

class ShortlistsData {
  final List<ShortlistRequestView> requests;
  final ShortlistPromise promise;
  const ShortlistsData({required this.requests, required this.promise});
}

final shortlistsProvider = FutureProvider<ShortlistsData>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final data = await ApiClient.instance.get('/shortlists') as Map<String, dynamic>;
  return ShortlistsData(
    requests: [for (final r in data['requests'] as List) ShortlistRequestView.fromJson(r as Map<String, dynamic>)],
    promise: ShortlistPromise.fromJson(data['promise'] as Map<String, dynamic>),
  );
});

final shortlistPromiseProvider = FutureProvider<ShortlistPromise>((ref) async {
  final data = await ApiClient.instance.get('/shortlists/promise') as Map<String, dynamic>;
  return ShortlistPromise.fromJson(data);
});

// ── Applicants (client) ──────────────────────────────────

class ApplicantsData {
  final List<JobApplication> applications;
  final ApplicantCap? cap;
  const ApplicantsData({required this.applications, required this.cap});
}

final applicantsProvider = FutureProvider.autoDispose.family<ApplicantsData, String>((ref, jobId) async {
  final data = await ApiClient.instance.get('/jobs/$jobId/applications') as Map<String, dynamic>;
  return ApplicantsData(
    applications: [for (final a in data['applications'] as List) JobApplication.fromJson(a as Map<String, dynamic>)],
    cap: data['cap'] == null ? null : ApplicantCap.fromJson(data['cap'] as Map<String, dynamic>),
  );
});

// ── Actions ──────────────────────────────────────────────

class DiscoveryActions {
  final Ref _ref;
  DiscoveryActions(this._ref);
  ApiClient get _api => ApiClient.instance;

  /// A structured post (S3). Returns the job and whether it was held for screening, with the reason.
  Future<({Job job, bool held, String? reason})> postJob(Map<String, dynamic> body) async {
    final data = await _api.post('/jobs', body: body) as Map<String, dynamic>;
    await _ref.read(jobsProvider.notifier).refresh();
    return (job: Job.fromJson(data['job'] as Map<String, dynamic>), held: data['heldForScreening'] as bool? ?? false, reason: data['screeningReason'] as String?);
  }

  /// Edits a post. A turned-down post goes back to screening; `resubmitted` says so.
  Future<({Job job, bool resubmitted})> editJob(String id, Map<String, dynamic> body) async {
    final data = await _api.patch('/jobs/$id', body: body) as Map<String, dynamic>;
    await _ref.read(jobsProvider.notifier).refresh();
    return (job: Job.fromJson(data['job'] as Map<String, dynamic>), resubmitted: data['resubmitted'] as bool? ?? false);
  }

  Future<void> apply(String jobId, {required int revision, required String answer, required List<Map<String, String>> pieces, required List<String> screeningAnswers}) async {
    await _api.post('/jobs/$jobId/apply', body: {'revision': revision, 'answer': answer, 'pieces': pieces, 'screeningAnswers': screeningAnswers});
    _ref.invalidate(jobDetailProvider(jobId));
    _ref.invalidate(invitationsProvider);
    await _ref.read(jobsProvider.notifier).refresh();
  }

  Future<void> saveSearch(String name, FeedFilters filters) async {
    await _api.post('/users/me/saved-searches', body: {'name': name, 'filters': filters.toSavedFilters(), 'alerts': true});
    _ref.invalidate(savedSearchesProvider);
  }

  /// Puts back a search that was just deleted (the Undo on its toast).
  Future<void> restoreSearch(SavedSearch s) async {
    await _api.post('/users/me/saved-searches', body: {'name': s.name, 'filters': s.filters, 'alerts': s.alerts});
    _ref.invalidate(savedSearchesProvider);
  }

  Future<void> setSearchAlerts(String id, bool on) async {
    await _api.patch('/users/me/saved-searches/$id', body: {'alerts': on});
    _ref.invalidate(savedSearchesProvider);
  }

  Future<void> deleteSearch(String id) async {
    await _api.delete('/users/me/saved-searches/$id');
    _ref.invalidate(savedSearchesProvider);
  }

  Future<void> respondInvitation(String id, {required bool accept}) async {
    await _api.post('/users/me/invitations/$id/respond', body: {'accept': accept});
    _ref.invalidate(invitationsProvider);
  }

  Future<void> answerAsk(String itemId, {required bool available}) async {
    await _api.post('/users/me/shortlist-asks/$itemId', body: {'available': available});
    _ref.invalidate(shortlistAsksProvider);
  }

  Future<void> invite(String jobId, String talentId, {String? message}) async {
    await _api.post('/jobs/$jobId/invitations', body: {'talentId': talentId, if (message != null && message.trim().isNotEmpty) 'message': message.trim()});
  }

  Future<void> setSaved(String talentId, {required bool saved}) async {
    if (saved) {
      await _api.post('/talents/$talentId/save');
    } else {
      await _api.delete('/talents/$talentId/save');
    }
    _ref.invalidate(savedTalentsProvider);
    _ref.invalidate(talentProfileViewProvider(talentId));
  }

  Future<void> requestShortlist(Map<String, dynamic> body) async {
    await _api.post('/shortlists', body: body);
    _ref.invalidate(shortlistsProvider);
  }

  Future<void> shortlistApplicant(String jobId, String applicationId, {required bool on}) async {
    await _api.post('/jobs/$jobId/applications/$applicationId/shortlist', body: {'shortlisted': on});
    _ref.invalidate(applicantsProvider(jobId));
  }

  Future<void> declineApplicant(String jobId, String applicationId) async {
    await _api.post('/jobs/$jobId/applications/$applicationId/decline');
    _ref.invalidate(applicantsProvider(jobId));
  }

  Future<void> reopen(String jobId) async {
    await _api.post('/jobs/$jobId/reopen');
    _ref.invalidate(applicantsProvider(jobId));
    _ref.invalidate(jobDetailProvider(jobId));
  }
}

final discoveryActionsProvider = Provider<DiscoveryActions>((ref) => DiscoveryActions(ref));
