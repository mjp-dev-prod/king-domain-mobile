import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/billing_gateway.dart';
import '../../providers/packages_provider.dart';
import 'kd_button.dart';
import 'kd_card.dart';
import 'kd_sheet.dart';

/// What a premium feature does, in plain words, before anything is bought.
class _Copy {
  final String title;
  final String what;
  final String limits;
  const _Copy(this.title, this.what, this.limits);
}

const _copy = {
  'reopen_job': _Copy(
    'Reopen applications',
    'Your job reached its limit of applicants, so it paused. Reopening lets another batch apply, starting now.',
    'It doesn\'t move your job above anyone else\'s, and the people who already applied stay exactly where they are.',
  ),
  'pre_apply_question': _Copy(
    'Ask before you apply',
    'Ask the client one question about the job before you apply. The answer is shown to everyone who applies, so nobody is kept in the dark.',
    'It doesn\'t put you ahead of anyone: your application is still in the order you send it.',
  ),
};

/// Offers a premium purchase and returns true once it is bought and verified, so the caller can retry what it was doing.
/// The price is read from Google Play itself. Nothing is completed on the phone until our server has checked the purchase
/// with Google, so a failed check never takes money for nothing.
Future<bool> offerPremium(BuildContext context, {required String feature, required String? productId}) async {
  final bought = await showKdSheet<bool>(context, builder: (_) => _PremiumBody(feature: feature, productId: productId));
  return bought == true;
}

class _PremiumBody extends ConsumerStatefulWidget {
  final String feature;
  final String? productId;
  const _PremiumBody({required this.feature, required this.productId});

  @override
  ConsumerState<_PremiumBody> createState() => _PremiumBodyState();
}

class _PremiumBodyState extends ConsumerState<_PremiumBody> {
  Future<BillingProduct?>? _product;
  String? _error;

  @override
  void initState() {
    super.initState();
    final id = widget.productId;
    if (id != null) _product = _load(id);
  }

  Future<BillingProduct?> _load(String id) async {
    final gateway = ref.read(billingGatewayProvider);
    if (!await gateway.available()) return null;
    return gateway.product(id);
  }

  Future<void> _buy() async {
    setState(() => _error = null);
    try {
      await ref.read(packageActionsProvider).buyPremium(widget.productId!, accountId: ref.read(authProvider).user?.id ?? '');
    } on BillingCancelled {
      throw const ShownError();
    } on BillingFailed catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy[widget.feature] ?? const _Copy('Premium', '', '');
    final status = ref.watch(premiumStatusProvider).valueOrNull;
    return KdSheetBody(
      title: copy.title,
      lead: copy.what,
      children: [
        const SizedBox(height: 12),
        Text(copy.limits, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2)),
        const SizedBox(height: 14),
        KdCard(
          tone: KdTone.brand,
          child: Row(children: [
            const Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryText),
            const SizedBox(width: 10),
            Expanded(child: Text(status?.rule.isNotEmpty == true ? status!.rule : 'Nobody on King Domain will ever ask you for money to get or do a job. Premium is optional and is only bought inside the app through Google Play.', style: AppTextStyles.bodySmall)),
          ]),
        ),
        const SizedBox(height: 14),
        if (widget.productId == null)
          Text('Buying isn\'t switched on yet. Nothing has been charged.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warn))
        else
          FutureBuilder<BillingProduct?>(
            future: _product,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
              final p = snap.data;
              if (p == null) return Text('Google Play isn\'t available on this phone right now, so there is nothing to buy. Nothing has been charged.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warn));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))),
                KdButton(label: 'Buy for ${p.price}', busyLabel: 'Buying', icon: Icons.lock_open_rounded, onPressed: _buy),
              ]);
            },
          ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Not now', onPressed: () => Navigator.of(context).pop(false)),
      ],
    );
  }
}
