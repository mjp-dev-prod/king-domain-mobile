import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/main.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/jobs/job_detail_screen.dart';

void main() {
  testWidgets('Welcome screen leads into sign-up email validation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: KingDomainApp()),
    );

    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets(
    'Job apply is gated on Verified status until simulated approval',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Seed a talent already past onboarding: one skill category, one
      // pending (not yet verified) proof item in it.
      container.read(talentProfileProvider.notifier)
        ..setSkillCategories(['Software & tech'])
        ..addProofItem(
          const ProofItem(
            id: 'proof-1',
            category: 'Software & tech',
            title: 'A sample project',
          ),
        );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: JobDetailScreen(jobId: 'job-2')),
        ),
      );
      await tester.pumpAndSettle();

      // Job Detail should show the gate for an unverified category.
      expect(find.text('Verification required'), findsOneWidget);

      // Simulate reviewer approval, matching the real proof-upload flow.
      container
          .read(talentProfileProvider.notifier)
          .simulateReviewApproval('proof-1');
      await tester.pumpAndSettle();

      expect(find.text('Apply for this job'), findsOneWidget);
    },
  );
}
