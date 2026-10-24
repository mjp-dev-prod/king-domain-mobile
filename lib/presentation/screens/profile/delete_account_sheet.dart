import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/account.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';

/// Delete account (docs/features/account-deletion-and-privacy.md). Says what goes and what is kept,
/// asks for the password again, and shows the server's answer in place: a wrong password inline, or,
/// while a job is in progress, the jobs that must be finished first.
void showDeleteAccountSheet(BuildContext context) {
  showKdSheet(context, builder: (_) => const _DeleteAccountBody());
}

class _DeleteAccountBody extends ConsumerStatefulWidget {
  const _DeleteAccountBody();

  @override
  ConsumerState<_DeleteAccountBody> createState() => _DeleteAccountBodyState();
}

class _DeleteAccountBodyState extends ConsumerState<_DeleteAccountBody> {
  final _password = TextEditingController();
  String? _error;
  List<ActiveContract>? _blocked;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      throw const ShownError();
    }
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).deleteAccount(password);
    } on ApiException catch (e) {
      final jobs = e.code == 'active_contracts' ? ActiveContract.listFrom(e.data) : const <ActiveContract>[];
      if (mounted) setState(() => jobs.isEmpty ? _error = e.message : _blocked = jobs);
      throw const ShownError();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    KdToast.show(context, 'Your account has been deleted.');
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    if (blocked != null) return _Blocked(jobs: blocked);

    final client = ref.watch(authProvider).user?.role == 'client';
    return KdSheetBody(
      title: 'Delete your account?',
      lead: 'This can\'t be undone.',
      children: [
        const SizedBox(height: 14),
        _Point(
          icon: Icons.delete_outline_rounded,
          title: 'Deleted',
          text: client
              ? 'Your photo and sign-in details, and any job nobody was hired for.'
              : 'Your profile, photo, proof of work, payout account and sign-in details.',
        ),
        const _Point(
          icon: Icons.receipt_long_outlined,
          title: 'Kept',
          text: 'Finished jobs and payments, kept without your name, so the other person\'s records stay correct.',
        ),
        const _Point(
          icon: Icons.hourglass_bottom_rounded,
          title: 'Not possible yet if…',
          text: 'You can\'t delete your account while you have a job in progress.',
        ),
        const SizedBox(height: 14),
        KdTextField(
          controller: _password,
          label: 'Your password',
          isPassword: true,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(liveRegion: true, child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))),
          ),
        const SizedBox(height: 16),
        KdButton(label: 'Delete my account', variant: KdButtonVariant.danger, busyLabel: 'Deleting', onPressed: _delete),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Keep my account', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _Point({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.text2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title),
                const SizedBox(height: 2),
                Text(text, style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The server refused because a contract is not finished: say which, plainly.
class _Blocked extends StatelessWidget {
  final List<ActiveContract> jobs;
  const _Blocked({required this.jobs});

  static String _status(String status) => switch (status) {
        'awaitingPayment' => 'Waiting for payment',
        'funded' => 'Paid, not started',
        'inProgress' => 'In progress',
        'submitted' => 'Delivered, in review',
        'changesRequested' => 'Changes requested',
        'disputed' => 'With our team',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: 'Finish these first',
      lead: 'You can\'t delete your account while a job is in progress. Once ${jobs.length == 1 ? 'it is' : 'they are'} finished or resolved, you can try again.',
      children: [
        const SizedBox(height: 14),
        for (final job in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KdCard(
              tone: KdTone.warn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title, style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Text('You\'re the ${job.role} · ${_status(job.status)}', style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Got it', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
