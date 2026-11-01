import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/dispute.dart';
import '../../providers/contract_extras_provider.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';

/// Where a King Domain agent can reach the person if something serious goes wrong and a ruling can't settle it (D35).
/// The purpose is stated here, in the words the server sends, before anything is asked for.
Future<bool?> showAddressSheet(BuildContext context) => showKdSheet<bool>(context, builder: (_) => const _AddressBody());

class _AddressBody extends ConsumerStatefulWidget {
  const _AddressBody();

  @override
  ConsumerState<_AddressBody> createState() => _AddressBodyState();
}

class _AddressBodyState extends ConsumerState<_AddressBody> {
  final _line = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  bool _filled = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_line, _city, _state]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Address a) {
    if (_filled) return;
    _filled = true;
    _line.text = a.line;
    _city.text = a.city;
    _state.text = a.state;
  }

  Future<void> _save() async {
    final a = Address(line: _line.text, city: _city.text, state: _state.text);
    if (a.line.trim().length < 5) {
      setState(() => _error = 'Write the street and house number.');
      throw const ShownError();
    }
    if (a.city.trim().length < 2) {
      setState(() => _error = 'Write the town or city.');
      throw const ShownError();
    }
    if (a.state.trim().length < 2) {
      setState(() => _error = 'Write the state.');
      throw const ShownError();
    }
    setState(() => _error = null);
    try {
      await ref.read(contractExtrasActionsProvider).saveAddress(a);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    KdToast.show(context, 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(addressProvider);
    return KdSheetBody(
      title: 'Where can we reach you?',
      lead: async.valueOrNull?.purpose ?? 'We ask for this so that, if something serious goes wrong on a job, a King Domain agent can follow it up with you in person.',
      children: async.when(
        loading: () => const [SizedBox(height: 16), SkeletonCard()],
        error: (_, _) => [
          const SizedBox(height: 12),
          ErrorState(message: 'Couldn\'t load your address. Check your connection and try again.', onRetry: () async => ref.invalidate(addressProvider)),
        ],
        data: (info) {
          _fill(info.address);
          return [
            const SizedBox(height: 14),
            KdTextField(controller: _line, label: 'Street and house number', textInputAction: TextInputAction.next),
            const SizedBox(height: 10),
            KdTextField(controller: _city, label: 'Town or city', textInputAction: TextInputAction.next),
            const SizedBox(height: 10),
            KdTextField(controller: _state, label: 'State'),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))],
            const SizedBox(height: 16),
            KdButton(label: 'Save', busyLabel: 'Saving', onPressed: _save),
            const SizedBox(height: 8),
            KdButton.secondary(label: 'Not now', onPressed: () => Navigator.of(context).pop(false)),
          ];
        },
      ),
    );
  }
}
