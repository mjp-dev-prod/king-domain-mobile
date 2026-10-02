import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';

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
    setState(() => _error = null);
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
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: ErrorState(
            message: 'Couldn\'t load this job. Check your connection and try again.',
            onRetry: () => ref.read(jobsProvider.notifier).refresh(),
          ),
        ),
        data: (jobs) {
          final job = jobs.where((j) => j.id == widget.jobId).firstOrNull;
          if (job == null) return const Center(child: Text('Could not find this job.'));
          // No contract at all: the 24-hour window ran out and the award was cancelled.
          if (job.contractStatus == null) return _cancelled(job);
          if (job.contractStatus != ContractStatus.awaitingPayment) return _funded(job);
          return LiveClock(builder: (_) => _awaiting(job));
        },
      ),
    );
  }

  Widget _page(Job job, StatusPill pill, List<Widget> cards, List<Widget> actions) {
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 200),
          children: [
            ContractHeader(title: job.title, sub: job.category, pill: pill),
            for (var i = 0; i < cards.length; i++)
              Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 60 * i), child: cards[i])),
          ],
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: ActionBar(children: actions)),
      ],
    );
  }

  Widget _awaiting(Job job) {
    final statusMessage = _statusMessage();
    final deadline = job.payByAt;
    final left = deadline == null ? null : timeLeft(deadline);
    final windowEnded = deadline != null && left == null;

    return _page(
      job,
      const StatusPill('Awaiting payment', tone: KdTone.warn),
      [
        _Breakdown(job: job),
        if (deadline != null)
          NoticeCard(
            tone: windowEnded ? KdTone.bad : KdTone.warn,
            icon: Icons.schedule_rounded,
            title: windowEnded ? 'Time ran out' : 'Pay within $left',
            body: windowEnded
                ? 'The 24-hour payment window has ended, so this award is being cancelled. You can award the job again.'
                : 'By ${formatDeadline(deadline)}. If it isn\'t paid by then, the award is cancelled and the other applicants come back.',
          ),
        if (job.paymentFailed && !_checkoutOpened)
          const NoticeCard(
            tone: KdTone.bad,
            icon: Icons.error_outline_rounded,
            title: 'Your last attempt failed',
            body: 'Nothing was charged. You can try again.',
          ),
        if (_checkoutOpened)
          NoticeCard(
            tone: _paymentStatus == 'failed' ? KdTone.bad : KdTone.warn,
            icon: Icons.open_in_new_rounded,
            title: 'Waiting for Paystack',
            body: statusMessage ?? 'Complete payment in the Paystack window. This screen updates on its own once Paystack confirms it.',
            waiting: _verifying ? 'Checking with Paystack' : null,
          ),
        if (_error != null)
          NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'Couldn\'t start payment', body: _error),
      ],
      [
        if (!_checkoutOpened)
          KdButton(
            label: 'Pay ${formatNaira(job.clientTotal)}',
            icon: Icons.lock_outline_rounded,
            busyLabel: 'Opening Paystack',
            onPressed: windowEnded ? null : _openCheckout,
          )
        else ...[
          KdButton(label: 'I\'ve paid — check status', busyLabel: 'Checking', onPressed: () => _verify()),
          KdButton.secondary(label: 'Reopen checkout', busyLabel: 'Opening', onPressed: _openCheckout),
        ],
      ],
    );
  }

  Widget _cancelled(Job job) => _page(
        job,
        const StatusPill('Cancelled'),
        [
          const NoticeCard(
            tone: KdTone.plain,
            icon: Icons.event_busy_outlined,
            title: 'Award cancelled',
            body: 'This award was cancelled because it wasn\'t paid for within 24 hours. The job is open again and nothing was charged.',
          ),
        ],
        [KdButton.secondary(label: 'Done', onPressed: () => Navigator.of(context).pop())],
      );

  Widget _funded(Job job) => _page(
        job,
        const StatusPill('Paid', tone: KdTone.ok, icon: Icons.check_rounded),
        [
          const NoticeCard(
            tone: KdTone.ok,
            icon: Icons.lock_outline_rounded,
            title: 'Payment secured',
            body: 'Payment confirmed. The talent will see this contract as funded and can start work.',
          ),
          _Breakdown(job: job),
        ],
        [KdButton.secondary(label: 'Done', onPressed: () => Navigator.of(context).pop())],
      );
}

/// What the client pays and where it goes. Gold is money's colour.
class _Breakdown extends StatelessWidget {
  final Job job;
  const _Breakdown({required this.job});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      hero: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOU PAY', style: AppTextStyles.label),
          const SizedBox(height: 6),
          Text(formatNaira(job.clientTotal), style: AppTextStyles.figure.copyWith(color: AppColors.money)),
          const SizedBox(height: 16),
          _Row(label: 'Goes to the talent', amount: job.budget),
          const Divider(height: 20, color: AppColors.line),
          _Row(label: '${AppBrand.name} fee (10%)', amount: job.platformFeeAmount ?? 0),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.text2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AppBrand.name} holds your payment. It\'s released to the talent only when you approve their delivery.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double amount;
  const _Row({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2))),
        Text(formatNaira(amount), style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}
