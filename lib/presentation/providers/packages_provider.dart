import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/debug_log.dart';
import '../../data/api_client.dart';
import '../../data/models/packages.dart';
import 'auth_provider.dart';
import 'billing_gateway.dart';

final myPackagesProvider = FutureProvider.autoDispose<MyPackages>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/users/me/packages') as Map<String, dynamic>;
  return MyPackages.fromJson(json);
});

/// Packages for browsing, optionally for one skill. Recently active first, like talents; no score, no paid place.
final packageBrowseProvider = FutureProvider.autoDispose.family<PackagePage, String?>((ref, skill) async {
  final json = await ApiClient.instance.get('/packages?limit=40${skill == null ? '' : '&skill=$skill'}') as Map<String, dynamic>;
  return PackagePage.fromJson(json);
});

final packageDetailProvider = FutureProvider.autoDispose.family<PackageDetail, String>((ref, id) async {
  final json = await ApiClient.instance.get('/packages/$id') as Map<String, dynamic>;
  return PackageDetail.fromJson(json);
});

final packageOrdersProvider = FutureProvider.autoDispose<List<PackageOrderItem>>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/users/me/package-orders') as Map<String, dynamic>;
  return [for (final o in (json['orders'] as List)) PackageOrderItem.fromJson(o as Map<String, dynamic>)];
});

final premiumStatusProvider = FutureProvider.autoDispose<PremiumStatus>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/premium/status') as Map<String, dynamic>;
  return PremiumStatus.fromJson(json);
});

/// The questions on a job a person may read: answered ones for everyone, plus their own (or all, for the client).
final jobQuestionsProvider = FutureProvider.autoDispose.family<List<JobQuestion>, String>((ref, jobId) async {
  final json = await ApiClient.instance.get('/jobs/$jobId/questions') as Map<String, dynamic>;
  return [for (final q in (json['questions'] as List)) JobQuestion.fromJson(q as Map<String, dynamic>)];
});

class PackageActions {
  final Ref _ref;
  PackageActions(this._ref);

  ApiClient get _api => ApiClient.instance;

  Future<void> save(String skillKey, String tier, {required String title, required String summary, required String included, required String formats, required num price, required int deliveryDays, required int quantity, required int revisions}) async {
    await _api.put('/users/me/packages/$skillKey/$tier', body: {'title': title, 'summary': summary, 'included': included, 'formats': formats, 'price': price, 'deliveryDays': deliveryDays, 'quantity': quantity, 'revisions': revisions});
    _ref.invalidate(myPackagesProvider);
  }

  Future<void> setPaused(String id, bool paused) async {
    await _api.patch('/users/me/packages/$id', body: {'status': paused ? 'paused' : 'active'});
    _ref.invalidate(myPackagesProvider);
  }

  Future<void> remove(String id) async {
    await _api.delete('/users/me/packages/$id');
    _ref.invalidate(myPackagesProvider);
  }

  /// Orders a package. Returns the job that was made for it.
  Future<String> order(String packageId, {required Map<String, dynamic> brief, String? note}) async {
    final json = await _api.post('/packages/$packageId/order', body: {'brief': brief, 'note': ?note}) as Map<String, dynamic>;
    _ref.invalidate(packageOrdersProvider);
    return json['jobId'] as String;
  }

  Future<void> answerOrder(String orderId, {required bool accept}) async {
    await _api.post('/package-orders/$orderId/${accept ? 'accept' : 'decline'}');
    _ref.invalidate(packageOrdersProvider);
  }

  Future<void> cancelOrder(String orderId) async {
    await _api.post('/package-orders/$orderId/cancel');
    _ref.invalidate(packageOrdersProvider);
  }

  // ── Premium ──

  /// Buys [productId] from Google Play, has our server check it with Google, and only then completes the purchase on the
  /// phone. Throws [BillingCancelled] if the person backs out, [BillingFailed] or [ApiException] with a reason otherwise.
  Future<void> buyPremium(String productId, {required String accountId}) async {
    final gateway = _ref.read(billingGatewayProvider);
    final purchase = await gateway.buy(productId, accountId: accountId);
    kdLog('premium', 'bought $productId, asking the server to check it');
    await _api.post('/premium/verify', body: {'productId': productId, 'purchaseToken': purchase.token});
    await gateway.complete(purchase);
    _ref.invalidate(premiumStatusProvider);
  }

  Future<void> ask(String jobId, String question) async {
    await _api.post('/jobs/$jobId/questions', body: {'question': question});
    _ref.invalidate(jobQuestionsProvider(jobId));
    _ref.invalidate(premiumStatusProvider);
  }

  Future<void> answerQuestion(String jobId, String questionId, String answer) async {
    await _api.post('/questions/$questionId/answer', body: {'answer': answer});
    _ref.invalidate(jobQuestionsProvider(jobId));
  }
}

final packageActionsProvider = Provider<PackageActions>((ref) => PackageActions(ref));
