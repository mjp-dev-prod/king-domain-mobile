import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/screens/onboarding/welcome_screen.dart';

void main() {
  testWidgets('fits a short phone with large system text: scrolls instead of overflowing', (tester) async {
    // 360 x 600 logical, text at 130%.
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const WelcomeScreen(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.maxScrollExtent, greaterThan(0),
        reason: 'the content is taller than this screen, so a fixed column would overflow');
    await tester.scrollUntilVisible(find.text('I already have an account'), 200);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
