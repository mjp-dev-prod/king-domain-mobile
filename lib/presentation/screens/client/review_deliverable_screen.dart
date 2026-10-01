import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/common/section_label.dart';

/// C3 — Deliverable review + approve. Approving is the real payout: the
/// backend transfers the job budget to the talent's Paystack recipient
/// (POST /jobs/:id/contract/approve), so failures there are surfaced as-is.
class ReviewDeliverableScreen extends ConsumerStatefulWidget {
  final String jobId;

  const ReviewDeliverableScreen({super.key, required this.jobId});

  @override
  ConsumerState<ReviewDeliverableScreen> createState() => _ReviewDeliverableScreenState();
}

class _ReviewDeliverableScreenState extends ConsumerState<ReviewDeliverableScreen> {
  bool _approving = false;
  String? _error;

  Future<void> _approve() async {
    setState(() {
      _approving = true;
      _error = null;
    });
    try {
      await ref.read(jobsProvider.notifier).approveDelivery(widget.jobId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery approved. Payment released.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _approving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);

    return jobsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not load this job.', style: AppTextStyles.bodyMedium)),
      ),
      data: (jobs) => _buildBody(context, jobs.firstWhere((j) => j.id == widget.jobId)),
    );
  }

  Widget _buildBody(BuildContext context, Job job) {
    final status = job.contractStatus;

    return Scaffold(
      appBar: AppBar(title: Text(job.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          children: [
            Text(formatNaira(job.budget), style: AppTextStyles.h3.copyWith(color: AppColors.gold)),
            const SizedBox(height: AppDimensions.xl),
            if (status != ContractStatus.submitted) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.openPending.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.openPending.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, size: AppDimensions.iconSm, color: AppColors.openPending),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Text(
                        status == ContractStatus.approved
                            ? 'You already approved this delivery. Payment has been released.'
                            : 'Nothing submitted yet — the talent hasn\'t delivered this work.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SectionLabel('Submission'),
              const SizedBox(height: AppDimensions.sm),
              if (job.deliverableNote != null) ...[
                Text(job.deliverableNote!, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppDimensions.md),
              ],
              if (job.deliverableFileUrl != null)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(job.deliverableFileUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.attach_file, size: AppDimensions.iconSm),
                  label: const Text('Open attached file'),
                ),
              if (job.deliverableUrl != null) ...[
                const SizedBox(height: AppDimensions.sm),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(job.deliverableUrl!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.link, size: AppDimensions.iconSm),
                  label: const Text('Open link'),
                ),
              ],
              const SizedBox(height: AppDimensions.xxl),
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Text(
                  'Approving sends ${formatNaira(job.budget)} to the talent\'s bank account. '
                  'This can\'t be undone.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateDim),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppDimensions.md),
                Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              ElevatedButton(
                onPressed: _approving ? null : _approve,
                child: _approving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2.5),
                      )
                    : const Text('Approve & release payment'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
