import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';

/// Where a talent's approved-job payments land. Look up the account name
/// first and have the talent confirm it's theirs, then save — the same
/// "verify, then add payee" flow as a banking app, so a mistyped digit
/// can't silently send someone's earnings to a stranger.
class PayoutAccountScreen extends ConsumerStatefulWidget {
  const PayoutAccountScreen({super.key});

  @override
  ConsumerState<PayoutAccountScreen> createState() => _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends ConsumerState<PayoutAccountScreen> {
  final _accountController = TextEditingController();
  Bank? _bank;
  bool _editing = false;
  bool _resolving = false;
  String? _resolvedName;
  String? _error;
  int _resolveRequest = 0;

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      _resolvedName = null;
      _error = null;
    });
    if (_bank != null && _accountController.text.length == 10) _resolve();
  }

  Future<void> _resolve() async {
    final request = ++_resolveRequest;
    setState(() => _resolving = true);
    try {
      final name = await ref.read(talentProfileProvider.notifier).resolvePayoutAccount(
            accountNumber: _accountController.text,
            bankCode: _bank!.code,
          );
      if (!mounted || request != _resolveRequest) return;
      setState(() => _resolvedName = name);
    } on ApiException catch (e) {
      if (!mounted || request != _resolveRequest) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted && request == _resolveRequest) setState(() => _resolving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      await ref.read(talentProfileProvider.notifier).savePayoutAccount(
            accountNumber: _accountController.text,
            bankCode: _bank!.code,
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Payout account saved.');
    Navigator.of(context).pop();
  }

  Future<void> _pickBank() async {
    final picked = await showKdSheet<Bank>(context, builder: (_) => const _BankPickerSheet());
    if (picked == null || !mounted) return;
    setState(() => _bank = picked);
    _onInputChanged();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(talentProfileProvider).valueOrNull?.payoutAccount;
    final showForm = current == null || _editing;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 180),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              ContractHeader(
                title: 'Payout account',
                sub: 'When a client approves your work, the full job budget is sent to this account.',
                pill: current == null
                    ? const StatusPill('Not set', tone: KdTone.warn)
                    : const StatusPill('Ready', tone: KdTone.ok, icon: Icons.check_rounded),
              ),
              if (current != null) ...[
                const SizedBox(height: 18),
                Text('CURRENT ACCOUNT', style: AppTextStyles.label),
                const SizedBox(height: 8),
                _AccountCard(account: current),
                if (!_editing) ...[
                  const SizedBox(height: 12),
                  KdButton.secondary(label: 'Change account', onPressed: () => setState(() => _editing = true)),
                ],
              ],
              if (showForm) ...[
                const SizedBox(height: 22),
                Text(current == null ? 'ADD YOUR BANK ACCOUNT' : 'NEW ACCOUNT', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Pressable(
                  onTap: _pickBank,
                  semanticLabel: 'Choose bank',
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Bank', suffixIcon: Icon(Icons.expand_more_rounded, color: AppColors.text3)),
                    isEmpty: _bank == null,
                    child: _bank == null ? null : Text(_bank!.name, style: AppTextStyles.bodyMedium),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  style: AppTextStyles.bodyMedium.copyWith(fontFeatures: const [FontFeature.tabularFigures()], letterSpacing: 1),
                  decoration: const InputDecoration(labelText: 'Account number', hintText: '10 digits'),
                  onChanged: (_) => _onInputChanged(),
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: AppMotion.state,
                  child: _resolving
                      ? Row(
                          key: const ValueKey('resolving'),
                          children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryText)),
                            const SizedBox(width: 10),
                            Text('Checking the account with the bank…', style: AppTextStyles.bodySmall),
                          ],
                        )
                      : _resolvedName != null
                          ? KdCard(
                              key: ValueKey(_resolvedName),
                              tone: KdTone.ok,
                              child: Row(
                                children: [
                                  const Icon(Icons.verified_outlined, size: 20, color: AppColors.ok),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Account holder', style: AppTextStyles.bodySmall),
                                        Text(_resolvedName!, style: AppTextStyles.title),
                                        const SizedBox(height: 2),
                                        Text('Only save this if the name above is yours.', style: AppTextStyles.hint),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _error != null
                              ? NoticeCard(key: const ValueKey('error'), tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'Couldn\'t check that account', body: _error)
                              : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
          if (showForm)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ActionBar(
                children: [
                  KdButton(
                    label: 'That\'s me — save account',
                    busyLabel: 'Saving',
                    onPressed: _resolvedName == null ? null : _save,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final PayoutAccount account;
  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
            child: const Icon(Icons.account_balance_outlined, color: AppColors.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.accountName, style: AppTextStyles.title),
                Text('${account.bankName ?? 'Bank'} · •••• ${account.accountNumberLast4}', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankPickerSheet extends ConsumerStatefulWidget {
  const _BankPickerSheet();

  @override
  ConsumerState<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends ConsumerState<_BankPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(banksProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 4, AppDimensions.gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose your bank', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'Search banks',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.text3),
                fillColor: AppColors.surface2,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: banksAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => ErrorState(message: 'Couldn\'t load the list of banks.', onRetry: () async => ref.invalidate(banksProvider)),
                data: (banks) {
                  final filtered = _query.isEmpty ? banks : banks.where((b) => b.name.toLowerCase().contains(_query)).toList();
                  if (filtered.isEmpty) {
                    return Center(child: Text('No bank matches "$_query".', style: AppTextStyles.bodySmall));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => Pressable(
                      onTap: () => Navigator.of(context).pop(filtered[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(filtered[i].name, style: AppTextStyles.bodyMedium),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
