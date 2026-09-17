import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
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
/// (product vision §05). Writes to the real backend now (PATCH
/// /users/me/profile — Sprint 2/4); full name lives on the User record
/// from signup, not collected again here.
class ProfileBuilderScreen extends ConsumerStatefulWidget {
  const ProfileBuilderScreen({super.key});

  @override
  ConsumerState<ProfileBuilderScreen> createState() =>
      _ProfileBuilderScreenState();
}

class _ProfileBuilderScreenState extends ConsumerState<ProfileBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _headlineController;
  late final TextEditingController _bioController;
  Set<String> _selectedCategories = {};
  bool _submitting = false;
  String? _error;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _headlineController = TextEditingController();
    _bioController = TextEditingController();
  }

  void _hydrateFromProfile() {
    if (_initialised) return;
    final profile = ref.read(talentProfileProvider).valueOrNull;
    if (profile == null) return;
    _headlineController.text = profile.headline;
    _bioController.text = profile.bio;
    _selectedCategories = profile.skillCategories.toSet();
    _initialised = true;
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one skill category.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(talentProfileProvider.notifier).updateProfile(
            headline: _headlineController.text,
            bio: _bioController.text,
            skillCategories: _selectedCategories.toList(),
          );
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProofUploadScreen()),
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
    // Runs once, the first time the profile fetch resolves, so the fields
    // pre-fill if the talent already started a profile before (e.g. came
    // back to this screen) without fighting what they're actively typing.
    ref.listen(talentProfileProvider, (previous, next) {
      if (!_initialised && next.hasValue) _hydrateFromProfile();
    });
    if (!_initialised) _hydrateFromProfile();

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
                StatefulBuilder(
                  builder: (context, setChipState) {
                    return Wrap(
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
                            setChipState(() {
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
                    );
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
                  onPressed: _submitting ? null : _continue,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.ink,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Continue to proof upload'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
