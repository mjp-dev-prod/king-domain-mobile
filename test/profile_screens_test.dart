import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/profile/profile_builder_screen.dart';
import 'package:king_domain/presentation/screens/profile/profile_overview_screen.dart';
import 'package:king_domain/presentation/screens/proof/proof_upload_screen.dart';

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

  @override
  Future<void> removeProofItem(String id) async => calls.add('remove:$id');
}

const _verified = ProofItem(id: 'p1', category: 'Design & creative', title: 'Cafe logo', status: ProofReviewStatus.verified);
const _pending = ProofItem(id: 'p2', category: 'Writing & content', title: 'Blog series');

Future<_Profile> _show(WidgetTester tester, Widget screen, TalentProfile profile) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final notifier = _Profile(profile);
  await tester.pumpWidget(ProviderScope(
    overrides: [talentProfileProvider.overrideWith(() => notifier)],
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
  group('overview', () {
    testWidgets('a new talent: proof is locked until the profile is done', (tester) async {
      await _show(tester, const ProfileOverviewScreen(), const TalentProfile());
      expect(find.text('0 of 3 done'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Pick your categories first.'), findsOneWidget);
    });

    testWidgets('proof sent but not yet checked reads as in review, not done', (tester) async {
      await _show(
        tester,
        const ProfileOverviewScreen(),
        const TalentProfile(headline: 'Writer', bio: 'b', skillCategories: ['Writing & content'], proofItems: [_pending]),
      );
      expect(find.text('In review'), findsOneWidget);
      expect(find.text('0 verified · 1 in review'), findsOneWidget);
    });
  });

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
        const TalentProfile(headline: 'Designer', bio: 'b', skillCategories: ['Design & creative'], proofItems: [_verified]),
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

  group('proof', () {
    const profile = TalentProfile(
      headline: 'h',
      bio: 'b',
      skillCategories: ['Design & creative', 'Writing & content'],
      proofItems: [_verified, _pending],
    );

    testWidgets('verified samples are permanent; samples in review can be withdrawn after asking', (tester) async {
      final p = await _show(tester, const ProofUploadScreen(), profile);
      expect(find.text('Verified'), findsWidgets);
      expect(find.text('In review'), findsOneWidget);
      expect(find.byTooltip('Remove'), findsOneWidget, reason: 'only the pending sample');

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(p.calls, isEmpty, reason: 'asks first');
      await tester.tap(find.text('Remove sample'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(p.calls, ['remove:p2']);
    });

    testWidgets('no categories yet: points to the profile', (tester) async {
      await _show(tester, const ProofUploadScreen(), const TalentProfile());
      expect(find.text('Pick your categories first'), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
    });
  });
}
