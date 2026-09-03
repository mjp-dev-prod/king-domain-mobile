import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/common/onboarding_step_header.dart';
import '../proof/proof_upload_screen.dart';

const _skillCategories = [
  'Software & tech',
  'Design & creative',
  'Writing & content',
  'Marketing & growth',
  'Tutoring & training',
  'Video & media',
];

/// T2 — Profile Builder. Builds the "living professional identity"
/// (product vision §05). Writes into talentProfileProvider so T3 and later
/// screens see the same in-progress state.
class ProfileBuilderScreen extends ConsumerStatefulWidget {
  const ProfileBuilderScreen({super.key});

  @override
  ConsumerState<ProfileBuilderScreen> createState() =>
      _ProfileBuilderScreenState();
}

class _ProfileBuilderScreenState extends ConsumerState<ProfileBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _headlineController;
  late final TextEditingController _bioController;
  late Set<String> _selectedCategories;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(talentProfileProvider);
    _nameController = TextEditingController(text: profile.fullName);
    _headlineController = TextEditingController(text: profile.headline);
    _bioController = TextEditingController(text: profile.bio);
    _selectedCategories = profile.skillCategories.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one skill category.')),
      );
      return;
    }

    final notifier = ref.read(talentProfileProvider.notifier);
    notifier.updateBasics(
      fullName: _nameController.text,
      headline: _headlineController.text,
      bio: _bioController.text,
    );
    notifier.setSkillCategories(_selectedCategories.toList());

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProofUploadScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OnboardingStepHeader(
                  step: 2,
                  totalSteps: 3,
                  title: 'Build your profile',
                  subtitle:
                      'This is what clients see first — make it count.',
                ),
                const SizedBox(height: AppDimensions.xl),
                TextFormField(
                  controller: _nameController,
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required.' : null,
                ),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: _headlineController,
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    labelText: 'Headline',
                    hintText: 'e.g. Frontend developer, Figma UI designer',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required.' : null,
                ),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: _bioController,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'A few sentences about what you do and how you work.',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required.' : null,
                ),
                const SizedBox(height: AppDimensions.lg),
                Text('Skill categories', style: AppTextStyles.h3),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'Pick every category you can back with proof in the next step.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppDimensions.md),
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: _skillCategories.map((category) {
                    final selected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category),
                      labelStyle: AppTextStyles.bodySmall.copyWith(
                        color: selected ? AppColors.ink : AppColors.paper,
                      ),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                        });
                      },
                      backgroundColor: AppColors.ink2,
                      selectedColor: AppColors.gold,
                      checkmarkColor: AppColors.ink,
                      side: BorderSide(
                        color: selected ? AppColors.gold : AppColors.ink3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusLg,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppDimensions.xxl),
                ElevatedButton(
                  onPressed: _continue,
                  child: const Text('Continue to proof upload'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
