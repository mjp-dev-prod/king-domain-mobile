import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/common/section_label.dart';
import '../payments/fund_contract_screen.dart';

/// C2 — Applicant list + single-award action. Awarding is atomic server-side
/// (one applicant selected, every other marked notSelected, contract created
/// awaitingPayment — one transaction), then hands straight to funding. See
/// docs/core/correction-talent-discovery-screen.md for why the award must
/// be atomic and single (not the old "matching" model).
class ApplicantsScreen extends ConsumerStatefulWidget {
  final Job job;

  const ApplicantsScreen({super.key, required this.job});

  @override
  ConsumerState<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends ConsumerState<ApplicantsScreen> {
  late Future<List<JobApplication>> _future;
  String? _awardingApplicationId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = ref.read(jobsProvider.notifier).listApplications(widget.job.id);
  }

  Future<void> _award(String applicationId) async {
    setState(() {
      _awardingApplicationId = applicationId;
      _error = null;
    });
    try {
      await ref.read(jobsProvider.notifier).awardApplication(widget.job.id, applicationId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => FundContractScreen(jobId: widget.job.id)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _awardingApplicationId = null;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final alreadyAwarded = widget.job.awardedApplicationId != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.job.title)),
      body: SafeArea(
        child: FutureBuilder<List<JobApplication>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load applicants.', style: AppTextStyles.bodyMedium),
              );
            }

            final applications = snapshot.data!;
            if (applications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.xl),
                  child: Text(
                    'No applicants yet.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              children: [
                if (alreadyAwarded) ...[
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: AppColors.settled.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.settled.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: AppDimensions.iconSm, color: AppColors.settled),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: Text(
                            'This job has been awarded.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.settled),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                ],
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                  ),
                  const SizedBox(height: AppDimensions.md),
                ],
                const SectionLabel('No ranking, no score — compared on existing proof only'),
                const SizedBox(height: AppDimensions.md),
                for (final application in applications) ...[
                  _ApplicantTile(
                    application: application,
                    awarded: application.id == widget.job.awardedApplicationId,
                    canAward: !alreadyAwarded,
                    awarding: _awardingApplicationId == application.id,
                    onAward: () => _award(application.id),
                  ),
                  const SizedBox(height: AppDimensions.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApplicantTile extends StatelessWidget {
  final JobApplication application;
  final bool awarded;
  final bool canAward;
  final bool awarding;
  final VoidCallback onAward;

  const _ApplicantTile({
    required this.application,
    required this.awarded,
    required this.canAward,
    required this.awarding,
    required this.onAward,
  });

  @override
  Widget build(BuildContext context) {
    final notSelected = application.status == 'notSelected';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.ink3,
              child: Text(
                application.talentName.isNotEmpty ? application.talentName[0].toUpperCase() : '?',
                style: AppTextStyles.bodyMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.talentName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: notSelected ? AppColors.slateDim : null,
                    ),
                  ),
                  if (awarded)
                    Text('Awarded', style: AppTextStyles.bodySmall.copyWith(color: AppColors.settled))
                  else if (notSelected)
                    Text('Not selected', style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateDim)),
                ],
              ),
            ),
            if (canAward)
              OutlinedButton(
                onPressed: awarding ? null : onAward,
                child: awarding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Award'),
              ),
          ],
        ),
      ),
    );
  }
}
