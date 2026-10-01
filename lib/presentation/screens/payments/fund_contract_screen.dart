import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/common/section_label.dart';

/// Client pays for an awarded job. Opens Paystack's hosted checkout in the
/// system in-app browser (Custom Tabs / SFSafariViewController) rather than
/// the card-only mobile SDK, so bank transfer and USSD stay available.
///
/// The browser can't report back, so the screen asks the server to verify
/// with Paystack when the app regains focus and on a timer while waiting —
/// a bank transfer can confirm minutes after the client leaves checkout.
class FundContractScreen extends ConsumerStatefulWidget {
  final String jobId;

  const FundContractScreen({super.key, required this.jobId});

  @override
  ConsumerState<FundContractScreen> createState() => _FundContractScreenState();
}

class _FundContractScreenState extends ConsumerState<FundContractScreen> with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 6);
  static const _pollFor = Duration(minutes: 10);

  bool _starting = false;
  bool _checkoutOpened = false;
  bool _verifying = false;
  String? _paymentStatus;
  String? _error;
  Timer? _poll;
  DateTime? _pollStartedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _checkoutOpened) _verify();
  }

  Future<void> _openCheckout() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final url = await ref.read(jobsProvider.notifier).startFunding(widget.jobId);
      if (url == null) return; // Already paid — the job refresh flips this screen to funded.

      bool launched;
      try {
        launched = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
      } on PlatformException {
        launched = false;
      }
      if (!mounted) return;
      if (!launched) {
        setState(() => _error = 'Could not open the payment page.');
        return;
      }
      setState(() {
        _checkoutOpened = true;
        _paymentStatus = null;
      });
      _startPolling();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _pollStartedAt = DateTime.now();
    _poll = Timer.periodic(_pollInterval, (_) {
      if (DateTime.now().difference(_pollStartedAt!) > _pollFor) {
        _poll?.cancel();
        return;
      }
      _verify(quiet: true);
    });
  }

  Future<void> _verify({bool quiet = false}) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      if (!quiet) _error = null;
    });
    try {
      final status = await ref.read(jobsProvider.notifier).verifyPayment(widget.jobId);
      if (!mounted) return;
      setState(() => _paymentStatus = status);
      if (status == 'success') _poll?.cancel();
    } on ApiException catch (e) {
      if (!mounted || quiet) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String? _statusMessage() => switch (_paymentStatus) {
    null => null,
    'failed' => 'That payment attempt failed. You can try again — nothing was charged for a failed attempt.',
    'abandoned' => 'Payment not completed yet. Finish it in the Paystack window, or reopen checkout.',
    _ => 'Paystack is still processing this payment. Bank transfers can take a few minutes to confirm.',
  };

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fund contract')),
      body: SafeArea(
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Could not load this job.', style: AppTextStyles.bodyMedium)),
          data: (jobs) {
            final job = jobs.where((j) => j.id == widget.jobId).firstOrNull;
            if (job == null) {
              return Center(child: Text('Could not find this job.', style: AppTextStyles.bodyMedium));
            }
            // No contract at all: the 24-hour window ran out and the award was cancelled.
            if (job.contractStatus == null) return _buildCancelled(job);
            final funded = job.contractStatus != ContractStatus.awaitingPayment;
            return funded ? _buildFunded(job) : _buildAwaiting(job);
          },
        ),
      ),
    );
  }

  Widget _buildAwaiting(Job job) {
    final statusMessage = _statusMessage();
    final showFailedBefore = job.paymentFailed && !_checkoutOpened;
    final deadline = job.payByAt;
    final left = deadline == null ? null : timeLeft(deadline);
    final windowEnded = deadline != null && left == null;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      children: [
        SectionLabel(job.category),
        const SizedBox(height: AppDimensions.sm),
        Text(job.title, style: AppTextStyles.h3),
        const SizedBox(height: AppDimensions.xl),
        _Breakdown(job: job),
        const SizedBox(height: AppDimensions.lg),
        Text(
          'King Domain holds your payment. It\'s released to the talent only '
          'when you approve their delivery.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: AppDimensions.lg),
        if (deadline != null) ...[
          _Notice(
            text: windowEnded
                ? 'The 24-hour payment window has ended, so this award is being cancelled. You can award the job again.'
                : "Pay within $left (by ${formatDeadline(deadline)}). If it isn't paid by then, the award is cancelled and the other applicants come back.",
            color: AppColors.openPending,
            icon: Icons.schedule,
          ),
          const SizedBox(height: AppDimensions.lg),
        ],
        if (showFailedBefore) ...[
          _Notice(text: 'Your last payment attempt failed. You can try again.', color: AppColors.openPending),
          const SizedBox(height: AppDimensions.md),
        ],
        if (_checkoutOpened) ...[
          _Notice(
            text: statusMessage ??
                'Complete payment in the Paystack window. This screen updates on its own once Paystack confirms it.',
            color: AppColors.openPending,
            busy: _verifying,
          ),
          const SizedBox(height: AppDimensions.md),
        ],
        if (_error != null) ...[
          Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending)),
          const SizedBox(height: AppDimensions.md),
        ],
        if (!_checkoutOpened)
          ElevatedButton(
            onPressed: _starting || windowEnded ? null : _openCheckout,
            child: _starting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2.5),
                  )
                : Text('Pay ${formatNaira(job.clientTotal)}'),
          )
        else ...[
          OutlinedButton(
            onPressed: _verifying ? null : () => _verify(),
            child: const Text('I\'ve paid — check status'),
          ),
          const SizedBox(height: AppDimensions.sm),
          TextButton(
            onPressed: _starting ? null : _openCheckout,
            child: const Text('Reopen checkout'),
          ),
        ],
      ],
    );
  }

  Widget _buildCancelled(Job job) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      children: [
        SectionLabel(job.category),
        const SizedBox(height: AppDimensions.sm),
        Text(job.title, style: AppTextStyles.h3),
        const SizedBox(height: AppDimensions.xl),
        _Notice(
          text: "This award was cancelled because it wasn't paid for within 24 hours. The job is open again and nothing was charged.",
          color: AppColors.openPending,
          icon: Icons.cancel_outlined,
        ),
        const SizedBox(height: AppDimensions.xl),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }

  Widget _buildFunded(Job job) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      children: [
        SectionLabel(job.category),
        const SizedBox(height: AppDimensions.sm),
        Text(job.title, style: AppTextStyles.h3),
        const SizedBox(height: AppDimensions.xl),
        _Notice(
          text: 'Payment confirmed. The talent will see this contract as funded and can start work.',
          color: AppColors.settled,
          icon: Icons.check_circle,
        ),
        const SizedBox(height: AppDimensions.lg),
        _Breakdown(job: job),
        const SizedBox(height: AppDimensions.xl),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  final Job job;

  const _Breakdown({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.ink2,
        border: Border.all(color: AppColors.ink3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        children: [
          _Row(label: 'Job budget — paid to the talent', amount: job.budget),
          const SizedBox(height: AppDimensions.sm),
          _Row(label: 'King Domain fee (10%)', amount: job.platformFeeAmount ?? 0),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.sm),
            child: Divider(color: AppColors.ink3, height: 1),
          ),
          _Row(label: 'Total', amount: job.clientTotal, emphasis: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double amount;
  final bool emphasis;

  const _Row({required this.label, required this.amount, this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    final style = emphasis
        ? AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)
        : AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim);
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(formatNaira(amount), style: style),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  final bool busy;

  const _Notice({required this.text, required this.color, this.icon = Icons.hourglass_empty, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          busy
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon, size: AppDimensions.iconSm, color: color),
          const SizedBox(width: AppDimensions.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color))),
        ],
      ),
    );
  }
}
