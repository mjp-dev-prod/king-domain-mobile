import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/common/section_label.dart';

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
  bool _saving = false;
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(talentProfileProvider.notifier).savePayoutAccount(
            accountNumber: _accountController.text,
            bankCode: _bank!.code,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout account saved.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBank() async {
    final picked = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink2,
      builder: (_) => const _BankPickerSheet(),
    );
    if (picked == null) return;
    setState(() => _bank = picked);
    _onInputChanged();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(talentProfileProvider).valueOrNull?.payoutAccount;
    final showForm = current == null || _editing;

    return Scaffold(
      appBar: AppBar(title: const Text('Payout account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          children: [
            Text(
              'When a client approves your work, the full job budget is sent '
              'to this account.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
            ),
            const SizedBox(height: AppDimensions.xl),
            if (current != null) ...[
              const SectionLabel('Current account'),
              const SizedBox(height: AppDimensions.sm),
              _AccountCard(account: current),
              if (!_editing) ...[
                const SizedBox(height: AppDimensions.md),
                OutlinedButton(
                  onPressed: () => setState(() => _editing = true),
                  child: const Text('Change account'),
                ),
              ],
              const SizedBox(height: AppDimensions.xl),
            ],
            if (showForm) ...[
              SectionLabel(current == null ? 'Add your bank account' : 'New account'),
              const SizedBox(height: AppDimensions.md),
              InkWell(
                onTap: _pickBank,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Bank',
                    suffixIcon: Icon(Icons.expand_more),
                  ),
                  isEmpty: _bank == null,
                  child: _bank == null ? null : Text(_bank!.name, style: AppTextStyles.bodyMedium),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _accountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  labelText: 'Account number',
                  hintText: '10 digits',
                ),
                onChanged: (_) => _onInputChanged(),
              ),
              const SizedBox(height: AppDimensions.lg),
              if (_resolving)
                Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: AppDimensions.sm),
                    Text('Checking account…', style: AppTextStyles.bodySmall),
                  ],
                ),
              if (_resolvedName != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.settled.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.settled.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined, size: AppDimensions.iconSm, color: AppColors.settled),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Account holder', style: AppTextStyles.bodySmall),
                            Text(
                              _resolvedName!,
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'Only save this if the name above is yours.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppDimensions.md),
                Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending)),
              ],
              const SizedBox(height: AppDimensions.xl),
              ElevatedButton(
                onPressed: _resolvedName == null || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2.5),
                      )
                    : const Text('That\'s me — save account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final PayoutAccount account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.ink2,
        border: Border.all(color: AppColors.ink3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_outlined, size: AppDimensions.iconSm, color: AppColors.slateDim),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.accountName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${account.bankName ?? 'Bank'} · •••• ${account.accountNumberLast4}',
                  style: AppTextStyles.bodySmall,
                ),
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

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.lg,
            right: AppDimensions.lg,
            top: AppDimensions.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              TextField(
                autofocus: true,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Search banks',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: AppDimensions.md),
              Expanded(
                child: banksAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Could not load banks.', style: AppTextStyles.bodyMedium),
                        TextButton(
                          onPressed: () => ref.invalidate(banksProvider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                  data: (banks) {
                    final filtered = _query.isEmpty
                        ? banks
                        : banks.where((b) => b.name.toLowerCase().contains(_query)).toList();
                    if (filtered.isEmpty) {
                      return Center(child: Text('No bank matches "$_query".', style: AppTextStyles.bodySmall));
                    }
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(filtered[i].name, style: AppTextStyles.bodyMedium),
                        onTap: () => Navigator.of(context).pop(filtered[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
