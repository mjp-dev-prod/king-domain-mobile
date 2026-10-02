import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../data/models/contract_history.dart';
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
  /// applicant on the job marked not-selected, contract created
  /// (awaitingPayment), all atomically server-side. See docs/core/
  /// correction-talent-discovery-screen.md for why this must be atomic.
  Future<void> awardApplication(String jobId, String applicationId) async {
    await ApiClient.instance.post('/jobs/$jobId/applications/$applicationId/award');
    await refresh();
  }

  /// Starts (or resumes) checkout. Returns null when the server found the
  /// previous checkout was already paid and funded the contract instead.
  Future<String?> startFunding(String jobId) async {
    final data = await ApiClient.instance.post('/jobs/$jobId/contract/fund');
    if (data['funded'] == true) {
      await refresh();
      return null;
    }
    return data['authorizationUrl'] as String;
  }

  /// Asks the server to check with Paystack. Returns Paystack's status
  /// for the latest checkout ('success', 'abandoned', 'failed', ...).
  Future<String> verifyPayment(String jobId) async {
    final data = await ApiClient.instance.post('/jobs/$jobId/contract/verify-payment');
    final status = data['paymentStatus'] as String;
    // Only these change server-side state; skipping the refresh otherwise
    // keeps background polling from re-fetching the whole feed every tick.
    if (status == 'success' || status == 'failed') await refresh();
    return status;
  }

  Future<Job> postJob({
    required String title,
    required String category,
    required String description,
    required double budget,
    required int deliveryDays,
  }) async {
    final data = await ApiClient.instance.post(
      '/jobs',
      body: {'title': title, 'category': category, 'description': description, 'budget': budget, 'deliveryDays': deliveryDays},
    );
    await refresh();
    return Job.fromJson(data['job'] as Map<String, dynamic>);
  }

  Future<void> startWork(String jobId) async {
    await ApiClient.instance.post('/jobs/$jobId/contract/start');
    await refresh();
  }

  Future<void> submitDeliverable(
    String jobId,
    String note, {
    String? url,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    await ApiClient.instance.postMultipart(
      '/jobs/$jobId/contract/submit',
      fields: {'deliverableNote': note, 'deliverableUrl': ?url},
      fileBytes: fileBytes,
      fileName: fileName,
    );
    await _afterContractChange(jobId);
  }

  Future<void> approveDelivery(String jobId) async {
    await ApiClient.instance.post('/jobs/$jobId/contract/approve');
    await _afterContractChange(jobId);
  }

  // ── Stage 2 (docs/features/stage-2-delivery-and-changes.md) ──────────

  /// Talent: ask for [days] more (1 to the job's original duration).
  Future<void> requestExtension(String jobId, {required int days, required String reason}) async {
    await ApiClient.instance.post('/jobs/$jobId/contract/extension', body: {'days': days, 'reason': reason.trim()});
    await _afterContractChange(jobId);
  }

  /// Client: grant or decline the open extension request.
  Future<void> answerExtension(String jobId, String extensionId, {required bool grant}) async {
    await ApiClient.instance.post(
      '/jobs/$jobId/contract/extension/$extensionId/answer',
      body: {'decision': grant ? 'grant' : 'decline'},
    );
    await _afterContractChange(jobId);
  }

  /// Client: send delivered work back. After the last round the server
  /// escalates to an admin instead; returns true when that happened.
  Future<bool> requestChanges(String jobId, {required String reason}) async {
    final data = await ApiClient.instance.post('/jobs/$jobId/contract/request-changes', body: {'reason': reason.trim()});
    await _afterContractChange(jobId);
    return data['escalated'] == true;
  }

  Future<void> _afterContractChange(String jobId) async {
    ref.invalidate(contractHistoryProvider(jobId));
    await refresh();
  }
}

/// Every delivery version, extension request and change round on a job's
/// contract (client and awarded talent only).
final contractHistoryProvider = FutureProvider.autoDispose.family<ContractHistory, String>((ref, jobId) async {
  final data = await ApiClient.instance.get('/jobs/$jobId/contract/history');
  return ContractHistory.fromJson(data as Map<String, dynamic>);
});

final jobsProvider = AsyncNotifierProvider<JobsNotifier, List<Job>>(JobsNotifier.new);
