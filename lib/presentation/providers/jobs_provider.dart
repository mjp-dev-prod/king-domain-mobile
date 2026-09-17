import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../data/models/job.dart';

/// Real backend now (king-domain-backend's /jobs routes — Sprint 3). Every
/// simulate* method from the old local mock is gone: award/fund, start,
/// submit, and approve are all real server-side state transitions, gated
/// by who's allowed to make them (see backend/src/user/jobsRoutes.js).
class JobsNotifier extends AsyncNotifier<List<Job>> {
  @override
  Future<List<Job>> build() => _fetch();

  Future<List<Job>> _fetch({String? category}) async {
    final query = category != null ? '?category=${Uri.encodeComponent(category)}' : '';
    final data = await ApiClient.instance.get('/jobs$query');
    return (data['jobs'] as List)
        .map((j) => Job.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<Job> fetchOne(String jobId) async {
    final data = await ApiClient.instance.get('/jobs/$jobId');
    return Job.fromJson(data['job'] as Map<String, dynamic>);
  }

  Future<void> applyTo(String jobId) async {
    await ApiClient.instance.post('/jobs/$jobId/apply');
    await refresh();
  }

  Future<List<JobApplication>> listApplications(String jobId) async {
    final data = await ApiClient.instance.get('/jobs/$jobId/applications');
    return (data['applications'] as List)
        .map((a) => JobApplication.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// The single-award action — one applicant selected, every other
  /// applicant on the job marked not-selected, contract created (funded),
  /// all atomically server-side. See docs/core/
  /// correction-talent-discovery-screen.md for why this must be atomic.
  Future<void> awardApplication(String jobId, String applicationId) async {
    await ApiClient.instance.post('/jobs/$jobId/applications/$applicationId/award');
    await refresh();
  }

  Future<Job> postJob({
    required String title,
    required String category,
    required String description,
    required double budget,
  }) async {
    final data = await ApiClient.instance.post(
      '/jobs',
      body: {'title': title, 'category': category, 'description': description, 'budget': budget},
    );
    await refresh();
    return Job.fromJson(data['job'] as Map<String, dynamic>);
  }

  Future<void> startWork(String jobId) async {
    await ApiClient.instance.post('/jobs/$jobId/contract/start');
    await refresh();
  }

  Future<void> submitDeliverable(String jobId, String note, {String? url}) async {
    await ApiClient.instance.post(
      '/jobs/$jobId/contract/submit',
      body: {'deliverableNote': note, if (url != null) 'deliverableUrl': url},
    );
    await refresh();
  }

  Future<void> approveDelivery(String jobId) async {
    await ApiClient.instance.post('/jobs/$jobId/contract/approve');
    await refresh();
  }
}

final jobsProvider = AsyncNotifierProvider<JobsNotifier, List<Job>>(JobsNotifier.new);
