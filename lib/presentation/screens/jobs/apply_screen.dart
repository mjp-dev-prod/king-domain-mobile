import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/common/section_label.dart';

/// T6 — Apply / Proposal. Submit with pitch + proof, gated on profile/proof
/// completeness (Milestone 03). Reaching this screen already implies the
/// talent is Verified in the job's category — JobDetailScreen enforces that
/// before the button that gets here is even enabled.
class ApplyScreen extends ConsumerStatefulWidget {
  final String jobId;

  const ApplyScreen({super.key, required this.jobId});

  @override
  ConsumerState<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends ConsumerState<ApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pitchController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _pitchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    ref.read(jobsProvider.notifier).applyTo(widget.jobId);

    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application submitted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobsProvider).firstWhere((j) => j.id == widget.jobId);
    final profile = ref.watch(talentProfileProvider);
    final proofForCategory = profile.proofItems
        .where((p) => p.category == job.category)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Apply')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: AppTextStyles.h3),
                const SizedBox(height: AppDimensions.xl),
                const SectionLabel('Attached proof'),
                const SizedBox(height: AppDimensions.sm),
                ...proofForCategory.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                    child: Row(
                      children: [
                        Icon(Icons.verified, size: 16, color: AppColors.settled),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: Text(item.title, style: AppTextStyles.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                const SectionLabel('Your pitch'),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: _pitchController,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText:
                        'Why are you a good fit? What\'s your approach, '
                        'and when could you start?',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 20) {
                      return 'Write at least a couple of sentences.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.xxl),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.ink,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Submit application'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
