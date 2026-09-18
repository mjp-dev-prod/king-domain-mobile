import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:king_domain/main.dart';

// The former second test here ("Job apply is gated on Verified status until
// simulated approval") seeded provider state via mock mutation methods
// (setSkillCategories, simulateReviewApproval) that no longer exist —
// talent_profile_provider.dart is a real, network-backed AsyncNotifier now
// (Sprint 4), and proof verification only happens through the real backend
// admin-review endpoint. Re-covering this gate needs an HTTP-mocked
// ApiClient, not a removed one-liner; not rebuilt yet.
void main() {
  testWidgets('Welcome screen leads into sign-up email validation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: KingDomainApp()),
    );
    // _RootRouter starts in a loading state while it restores/attempts a
    // session (main.dart). No real backend or secure-storage platform
    // channel exists in the widget-test environment, so a bounded pump
    // is used instead of pumpAndSettle (which times out waiting on that
    // I/O to resolve rather than settling).
    await tester.pump(const Duration(seconds: 6));

    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);

    // The role picker + confirm-password field push the submit button below
    // the fold on a small test viewport. The button is already built (just
    // off-screen), so ensureVisible — not scrollUntilVisible, which is for
    // not-yet-built lazy-list items and needs an unambiguous single
    // Scrollable — is the right call here.
    await tester.ensureVisible(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });
}
