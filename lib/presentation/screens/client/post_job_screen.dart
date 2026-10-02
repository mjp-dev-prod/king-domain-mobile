import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/skill_categories.dart';
import '../../../data/api_client.dart';
import '../../providers/jobs_provider.dart';
import '../../../core/formatting/deadline.dart';
import '../../widgets/common/section_label.dart';
import '../../widgets/kit/kd_fields.dart';

/// C1 — Post a job. Backend route (POST /jobs) has been real and tested
/// since Sprint 3 (jobsRoutes.js) — this is the first UI to ever call it.
/// Category must be one of kSkillCategories, same list a talent picks from
/// in ProfileBuilderScreen, since applying is gated on Verified proof in
/// the job's exact category string.
class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  String? _category;
  /// Days the talent gets, counted from when the client pays (stage 2:
  /// docs/features/stage-2-delivery-and-changes.md). Backend accepts 1–60.
  int _deliveryDays = 7;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      setState(() => _error = 'Pick a category.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(jobsProvider.notifier).postJob(
            title: _titleController.text.trim(),
            category: _category!,
            description: _descriptionController.text.trim(),
            budget: double.parse(_budgetController.text.trim()),
            deliveryDays: _deliveryDays,
          );
      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job posted.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Category'),
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: kSkillCategories.map((category) {
                    final selected = _category == category;
                    return ChoiceChip(
                      label: Text(category),
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        color: selected ? AppColors.primaryText : AppColors.text2,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = category),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppDimensions.lg),
                const SectionLabel('Title'),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: _titleController,
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Landing page redesign for a campus app',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.lg),
                const SectionLabel('Description'),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: _descriptionController,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'What needs to be done? Scope, deliverables, timeline.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 20) {
                      return 'Add a bit more detail.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.lg),
                const SectionLabel('Budget (₦)'),
                const SizedBox(height: AppDimensions.sm),
                TextFormField(
                  controller: _budgetController,
                  style: AppTextStyles.bodyMedium,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  decoration: const InputDecoration(hintText: 'e.g. 45000'),
                  validator: (value) {
                    final n = double.tryParse(value?.trim() ?? '');
                    if (n == null || n <= 0) {
                      return 'Enter a valid amount.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.lg),
                const SectionLabel('Delivery time'),
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.sm,
                  children: [
                    for (final d in const [3, 5, 7, 14])
                      ChoiceChip(
                        label: Text('$d days'),
                        selected: _deliveryDays == d,
                        onSelected: (_) => setState(() => _deliveryDays = d),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),
                DayStepper(value: _deliveryDays, min: 1, max: 60, onChanged: (v) => setState(() => _deliveryDays = v)),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'The clock starts when you pay. If you paid now, the work would be due '
                  '${formatDeadline(DateTime.now().add(Duration(days: _deliveryDays)))}.',
                  style: AppTextStyles.bodySmall,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad),
                  ),
                ],
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
                      : const Text('Post job'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
