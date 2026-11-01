import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/debug_log.dart';
import '../../data/api_client.dart';
import '../../data/models/contract_extras.dart';
import '../../data/models/dispute.dart';
import 'auth_provider.dart';
import 'jobs_provider.dart';
import 'skill_submissions_provider.dart' show PickedFile, blobUploaderProvider;

/// The start proof on a job's contract (client and awarded talent only).
final startProofProvider = FutureProvider.autoDispose.family<StartProof, String>((ref, jobId) async {
  final json = await ApiClient.instance.get('/jobs/$jobId/contract/start-proof') as Map<String, dynamic>;
  return StartProof.fromJson(json);
});

final draftsProvider = FutureProvider.autoDispose.family<DraftList, String>((ref, jobId) async {
  final json = await ApiClient.instance.get('/jobs/$jobId/contract/drafts') as Map<String, dynamic>;
  return DraftList.fromJson(json);
});

/// "Something's wrong" for one job: the open or last dispute, what the person may pick, and what is held.
final disputeProvider = FutureProvider.autoDispose.family<DisputeState, String>((ref, jobId) async {
  final json = await ApiClient.instance.get('/jobs/$jobId/contract/dispute') as Map<String, dynamic>;
  return DisputeState.fromJson(json);
});

/// Where a King Domain agent can reach the person in a serious escalation, and why it is asked for.
final addressProvider = FutureProvider.autoDispose<AddressInfo>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/users/me/address') as Map<String, dynamic>;
  return AddressInfo.fromJson(json);
});

final receiptProvider = FutureProvider.autoDispose.family<Receipt, String>((ref, jobId) async {
  final json = await ApiClient.instance.get('/jobs/$jobId/contract/receipt') as Map<String, dynamic>;
  return Receipt.fromJson(json);
});

final availabilityProvider = FutureProvider<Availability>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/jobs/availability') as Map<String, dynamic>;
  return Availability.fromJson(json);
});

/// The rate the team set for showing dollars as naira and the other way. Null rate means nothing is converted.
final fxRateProvider = FutureProvider<FxRate>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/rates') as Map<String, dynamic>;
  return FxRate.fromJson(json);
});

/// What money is shown in ('NGN' or 'USD'). Amounts in the other currency are marked "about" (D37).
class DisplayCurrencyNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    ref.watch(authProvider.select((s) => s.user?.id));
    final json = await ApiClient.instance.get('/users/me/settings') as Map<String, dynamic>;
    return json['displayCurrency'] as String? ?? 'NGN';
  }

  Future<void> choose(String currency) async {
    final json = await ApiClient.instance.patch('/users/me/settings', body: {'displayCurrency': currency}) as Map<String, dynamic>;
    state = AsyncData(json['displayCurrency'] as String? ?? currency);
  }
}

final displayCurrencyProvider = AsyncNotifierProvider<DisplayCurrencyNotifier, String>(DisplayCurrencyNotifier.new);

class ContractExtrasActions {
  final Ref _ref;
  ContractExtrasActions(this._ref);

  ApiClient get _api => ApiClient.instance;
  String _base(String jobId) => '/jobs/$jobId/contract';

  void _refreshProof(String jobId) {
    _ref.invalidate(startProofProvider(jobId));
  }

  /// After a step that moves the contract itself (sent, accepted), the job list is refreshed too.
  Future<void> _refreshAll(String jobId) async {
    _refreshProof(jobId);
    _ref.invalidate(contractHistoryProvider(jobId));
    await _ref.read(jobsProvider.notifier).refresh();
  }

  /// Saves a typed part (an outline) or a link.
  Future<void> saveText(String jobId, String fieldKey, String text) async {
    await _api.post('${_base(jobId)}/start-proof/items', body: {'fieldKey': fieldKey, 'text': text});
    _refreshProof(jobId);
  }

  /// Asks for a link, sends the file to it, then confirms. A failed upload leaves nothing half-made.
  Future<void> addProofFile(String jobId, String fieldKey, PickedFile file, {void Function(double fraction)? onProgress}) async {
    final json = await _api.post('${_base(jobId)}/start-proof/files', body: {'fieldKey': fieldKey, 'name': file.name, 'contentType': file.contentType, 'sizeBytes': file.size}) as Map<String, dynamic>;
    final itemId = json['itemId'] as String;
    final upload = json['upload'] as Map<String, dynamic>;
    kdLog('start-proof', 'ticket for ${file.name} (${file.size} bytes) field=$fieldKey item=$itemId');
    try {
      await _ref.read(blobUploaderProvider).put(upload['url'] as String, {for (final e in (upload['headers'] as Map).entries) e.key as String: e.value as String}, file.open(), file.size, onProgress: onProgress);
      await _api.post('${_base(jobId)}/start-proof/files/$itemId/complete');
      kdLog('start-proof', 'confirmed item=$itemId: the server read it back from storage');
    } catch (e) {
      kdLog('start-proof', 'FAILED item=$itemId ${file.name}: $e. Removing the half-made file.');
      try {
        await _api.delete('${_base(jobId)}/start-proof/items/$itemId');
      } catch (_) {
        // A pending file is invisible to the talent and the client; the server clears it with the proof.
      }
      _refreshProof(jobId);
      rethrow;
    }
    _refreshProof(jobId);
  }

  Future<void> removeItem(String jobId, String itemId) async {
    await _api.delete('${_base(jobId)}/start-proof/items/$itemId');
    _refreshProof(jobId);
  }

  Future<void> submitProof(String jobId) async {
    await _api.post('${_base(jobId)}/start-proof/submit');
    await _refreshAll(jobId);
  }

  Future<void> acceptProof(String jobId) async {
    await _api.post('${_base(jobId)}/start-proof/accept');
    await _refreshAll(jobId);
  }

  Future<void> objectToProof(String jobId, {required String reasonCode, required String note}) async {
    await _api.post('${_base(jobId)}/start-proof/object', body: {'reasonCode': reasonCode, 'note': note});
    await _refreshAll(jobId);
  }

  // ── Something's wrong ──

  Future<void> _afterDispute(String jobId) async {
    _ref.invalidate(disputeProvider(jobId));
    _ref.invalidate(contractHistoryProvider(jobId));
    await _ref.read(jobsProvider.notifier).refresh();
  }

  Future<void> openDispute(String jobId, {required String problem, required String note}) async {
    await _api.post('${_base(jobId)}/dispute', body: {'problem': problem, 'note': note});
    await _afterDispute(jobId);
  }

  Future<void> offerWayOut(String jobId, {required String kind, Map<String, dynamic>? params, String? note}) async {
    await _api.post('${_base(jobId)}/dispute/proposals', body: {'kind': kind, 'params': params ?? {}, 'note': ?note});
    await _afterDispute(jobId);
  }

  Future<void> answerOffer(String jobId, String offerId, {required bool accept}) async {
    await _api.post('${_base(jobId)}/dispute/proposals/$offerId/answer', body: {'decision': accept ? 'accept' : 'decline'});
    await _afterDispute(jobId);
  }

  Future<void> askTeamToDecide(String jobId) async {
    await _api.post('${_base(jobId)}/dispute/escalate');
    await _afterDispute(jobId);
  }

  /// Three days past the delivery date with nothing delivered: cancel for a refund of what is held.
  Future<double> cancelForRefund(String jobId) async {
    final json = await _api.post('${_base(jobId)}/cancel') as Map<String, dynamic>;
    await _afterDispute(jobId);
    return (json['refund'] as num?)?.toDouble() ?? 0;
  }

  Future<void> saveAddress(Address a) async {
    await _api.put('/users/me/address', body: {'line': a.line.trim(), 'city': a.city.trim(), 'state': a.state.trim()});
    _ref.invalidate(addressProvider);
  }

  /// Shares work in progress. Files go straight to storage; if any fails the draft is not kept.
  Future<void> shareDraft(String jobId, {required String note, required List<PickedFile> files, void Function(String name, double fraction)? onProgress}) async {
    final json = await _api.post('${_base(jobId)}/drafts', body: {
      'note': note,
      'files': [for (final f in files) {'name': f.name, 'contentType': f.contentType, 'sizeBytes': f.size}],
    }) as Map<String, dynamic>;
    final draftId = json['draftId'] as String;
    final uploads = (json['uploads'] as List).cast<Map<String, dynamic>>();
    for (var i = 0; i < files.length; i++) {
      final u = uploads[i];
      kdLog('drafts', 'sending ${files[i].name} (${files[i].size} bytes) for draft=$draftId');
      await _ref.read(blobUploaderProvider).put(u['url'] as String, {for (final e in (u['headers'] as Map).entries) e.key as String: e.value as String}, files[i].open(), files[i].size, onProgress: (v) => onProgress?.call(files[i].name, v));
    }
    await _api.post('${_base(jobId)}/drafts/$draftId/complete');
    _ref.invalidate(draftsProvider(jobId));
  }
}

final contractExtrasActionsProvider = Provider<ContractExtrasActions>((ref) => ContractExtrasActions(ref));
