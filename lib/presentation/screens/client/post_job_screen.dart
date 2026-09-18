import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/skill_categories.dart';
import '../../../data/api_client.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/common/section_label.dart';

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
                        color: selected ? AppColors.ink : AppColors.paper,
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = category),
                      backgroundColor: AppColors.ink2,
                      selectedColor: AppColors.gold,
                      side: BorderSide(
                        color: selected ? AppColors.gold : AppColors.ink3,
                      ),
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
                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
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
