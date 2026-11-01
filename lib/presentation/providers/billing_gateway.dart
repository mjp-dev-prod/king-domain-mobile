import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/debug_log.dart';

/// What the store says about a product: the price is read from Google Play itself, never typed into the app.
class BillingProduct {
  final String id;
  final String title;
  final String price;
  const BillingProduct({required this.id, required this.title, required this.price});
}

/// A purchase the person made, waiting for our server to check it with Google before it is completed.
class BillingPurchase {
  final String productId;
  /// On Android this is the purchase token the server asks Google about.
  final String token;
  final Object? handle;
  const BillingPurchase({required this.productId, required this.token, this.handle});
}

class BillingCancelled implements Exception {
  const BillingCancelled();
}

class BillingFailed implements Exception {
  final String message;
  const BillingFailed(this.message);
  @override
  String toString() => message;
}

/// Google Play Billing, behind a seam so screens can be tested without a phone or a store.
abstract class BillingGateway {
  Future<bool> available();
  Future<BillingProduct?> product(String productId);

  /// Starts the purchase and waits until Google Play says it is paid. [accountId] is attached so a token can't be moved to
  /// another account. Throws [BillingCancelled] if the person backs out, [BillingFailed] with a reason otherwise.
  Future<BillingPurchase> buy(String productId, {required String accountId});

  /// Completes the purchase on the phone. Called only after our server verified it, so a purchase we couldn't verify is
  /// never completed (and Google Play refunds an uncompleted purchase on its own after three days).
  Future<void> complete(BillingPurchase purchase);
}

class PlayBillingGateway implements BillingGateway {
  const PlayBillingGateway();

  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Future<bool> available() => _iap.isAvailable();

  @override
  Future<BillingProduct?> product(String productId) async {
    final response = await _iap.queryProductDetails({productId});
    final p = response.productDetails.where((d) => d.id == productId).firstOrNull;
    return p == null ? null : BillingProduct(id: p.id, title: p.title, price: p.price);
  }

  @override
  Future<BillingPurchase> buy(String productId, {required String accountId}) async {
    final response = await _iap.queryProductDetails({productId});
    final details = response.productDetails.where((d) => d.id == productId).firstOrNull;
    if (details == null) throw const BillingFailed('This isn\'t available in your store yet.');

    final done = Completer<BillingPurchase>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = _iap.purchaseStream.listen((events) {
      for (final p in events) {
        if (p.productID != productId) continue;
        kdLog('billing', 'purchase $productId status=${p.status.name}');
        switch (p.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (!done.isCompleted) done.complete(BillingPurchase(productId: productId, token: p.verificationData.serverVerificationData, handle: p));
          case PurchaseStatus.canceled:
            if (!done.isCompleted) done.completeError(const BillingCancelled());
          case PurchaseStatus.error:
            if (!done.isCompleted) done.completeError(BillingFailed(p.error?.message ?? 'The purchase didn\'t go through.'));
          case PurchaseStatus.pending:
            break;
        }
      }
    }, onError: (Object e) {
      if (!done.isCompleted) done.completeError(BillingFailed('$e'));
    });
    try {
      // autoConsume is off on purpose: our server consumes it after checking it, and only then do we complete it here.
      final started = await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: details, applicationUserName: accountId), autoConsume: false);
      if (!started) throw const BillingFailed('The store didn\'t start the purchase.');
      return await done.future.timeout(const Duration(minutes: 10), onTimeout: () => throw const BillingFailed('The purchase took too long. If you were charged, it will be sorted out; try again.'));
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> complete(BillingPurchase purchase) async {
    final p = purchase.handle;
    if (p is PurchaseDetails && p.pendingCompletePurchase) await _iap.completePurchase(p);
  }
}

final billingGatewayProvider = Provider<BillingGateway>((ref) => const PlayBillingGateway());
