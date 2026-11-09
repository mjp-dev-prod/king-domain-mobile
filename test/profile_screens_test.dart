import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/skill_submission.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/skill_submissions_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/profile/profile_builder_screen.dart';

class _Profile extends TalentProfileNotifier {
  _Profile(this.profile);
  TalentProfile profile;
  final calls = <String>[];

  @override
  Future<TalentProfile> build() async => profile;

  @override
  Future<void> updateProfile({String? headline, String? bio, List<String>? skillCategories}) async {
    calls.add('update:$headline|$bio|${skillCategories?.join(',')}');
  }

}

/// Verified in a skill whose work is in this category: that is what keeps a category on the profile.
const _verifiedDesign = SkillHub(
  uploadsAvailable: true,
  skills: [SkillHubEntry(skillKey: 'graphic-design', label: 'Graphic design', category: 'Design & creative', state: SkillState.verified, currentSubmissionId: 's1', attempts: 1, restriction: null, rubricDraft: false)],
);

Future<_Profile> _show(WidgetTester tester, Widget screen, TalentProfile profile, {SkillHub hub = const SkillHub(skills: [], uploadsAvailable: true)}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final notifier = _Profile(profile);
  await tester.pumpWidget(ProviderScope(
    overrides: [talentProfileProvider.overrideWith(() => notifier), skillHubProvider.overrideWith((ref) async => hub)],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)), child: const Text('open')),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return notifier;
}

Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  group('builder', () {
    testWidgets('pre-fills, and saves categories in the canonical order', (tester) async {
      final p = await _show(
        tester,
        const ProfileBuilderScreen(),
        const TalentProfile(headline: 'Designer', bio: 'I make brands.', skillCategories: ['Design & creative']),
      );
      expect(find.text('Designer'), findsOneWidget);

      await tester.tap(find.text('Software & tech'));
      await tester.pump();
      await tester.tap(find.text('Save profile'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(p.calls, ['update:Designer|I make brands.|Software & tech,Design & creative']);
      await _drainToasts(tester);
    });

    testWidgets('a verified category cannot be unticked', (tester) async {
      final p = await _show(
        tester,
        const ProfileBuilderScreen(),
        const TalentProfile(headline: 'Designer', bio: 'b', skillCategories: ['Design & creative']),
        hub: _verifiedDesign,
      );
      await tester.tap(find.text('Design & creative'));
      await tester.pump();
      expect(find.textContaining('stays on your profile'), findsOneWidget);

      await tester.tap(find.text('Save profile'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(p.calls.single, endsWith('|Design & creative'));
      await _drainToasts(tester);
    });

    testWidgets('no categories: save is off and says why', (tester) async {
      await _show(tester, const ProfileBuilderScreen(), const TalentProfile(headline: 'h', bio: 'b'));
      expect(find.text('Pick at least one category.'), findsOneWidget);
    });
  });

}
