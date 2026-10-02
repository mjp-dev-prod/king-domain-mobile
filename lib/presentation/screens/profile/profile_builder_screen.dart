import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/skill_categories.dart';
import '../../../data/api_client.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/status_pill.dart';

/// Profile builder: the "living professional identity" (product vision §05)
/// clients see first. PATCH /users/me/profile; full name comes from signup.
/// Save sits in a sticky bar that rides above the keyboard (the old screen
/// hid it behind the keyboard: docs/research/ui-audit-2026-10-01.md).
class ProfileBuilderScreen extends ConsumerStatefulWidget {
  const ProfileBuilderScreen({super.key});

  @override
  ConsumerState<ProfileBuilderScreen> createState() => _ProfileBuilderScreenState();
}

class _ProfileBuilderScreenState extends ConsumerState<ProfileBuilderScreen> {
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  Set<String> _categories = {};
  bool _bioValid = false;
  bool _initialised = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill before any listener exists; a profile that arrives later is
    // handled by the ref.listen in build (which runs outside the build).
    _hydrate(ref.read(talentProfileProvider).valueOrNull);
    _headline.addListener(() => setState(() {}));
  }

  void _hydrate(TalentProfile? profile) {
    if (_initialised || profile == null) return;
    _headline.text = profile.headline;
    _bio.text = profile.bio;
    _categories = profile.skillCategories.toSet();
    _initialised = true;
  }

  @override
  void dispose() {
    _headline.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _valid => _headline.text.trim().isNotEmpty && _bioValid && _categories.isNotEmpty;

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      await ref.read(talentProfileProvider.notifier).updateProfile(
            headline: _headline.text.trim(),
            bio: _bio.text.trim(),
            skillCategories: kSkillCategories.where(_categories.contains).toList(),
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Profile saved.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(talentProfileProvider, (_, next) {
      if (!_initialised && next.hasValue) setState(() => _hydrate(next.value));
    });
    final profile = ref.watch(talentProfileProvider).valueOrNull;
    final verifiedIn = {
      for (final p in profile?.proofItems ?? const <ProofItem>[])
        if (p.status == ProofReviewStatus.verified) p.category,
    };

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 160),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              ContractHeader(
                title: 'Your profile',
                sub: 'What clients see first, next to your verified work.',
                pill: profile?.isProfileComplete == true
                    ? const StatusPill('Complete', tone: KdTone.ok, icon: Icons.check_rounded)
                    : const StatusPill('Incomplete', tone: KdTone.brand),
              ),
              const SizedBox(height: 20),
              Text('Headline', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _headline,
                maxLength: 80,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(hintText: 'e.g. Brand designer · Figma and Illustrator'),
              ),
              ReasonField(
                controller: _bio,
                label: 'About you',
                hint: 'What you do, what you\'ve made, and how you like to work.',
                min: 1,
                max: 600,
                onValidChanged: (v) => setState(() => _bioValid = v),
              ),
              const SizedBox(height: 8),
              Text('Categories you work in', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Pick every one you can back with a work sample. A person checks each before you can apply in it.', style: AppTextStyles.hint),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in kSkillCategories)
                    KdChoiceChip(
                      label: c,
                      selected: _categories.contains(c),
                      onTap: () {
                        if (verifiedIn.contains(c)) {
                          KdToast.show(context, 'You\'re verified in $c, so it stays on your profile.', kind: ToastKind.info);
                          return;
                        }
                        setState(() => _categories.contains(c) ? _categories.remove(c) : _categories.add(c));
                      },
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'Couldn\'t save', body: _error),
              ],
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ActionBar(
              children: [
                KdButton(label: 'Save profile', busyLabel: 'Saving', onPressed: _valid ? _save : null),
                if (!_valid)
                  Text(
                    _categories.isEmpty ? 'Pick at least one category.' : 'Add a headline and a few words about you.',
                    style: AppTextStyles.hint,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
