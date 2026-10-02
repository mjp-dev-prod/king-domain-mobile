import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/screens/onboarding/verify_email_screen.dart';

class _Auth extends AuthNotifier {
  static const goodCode = '123456';
  final calls = <String>[];

  @override
  AuthState build() => const AuthState(loading: false);

  @override
  Future<void> verifyEmail(String code) async {
    calls.add('verify:$code');
    if (code != goodCode) throw ApiException('That code is incorrect or has expired.', 400);
  }

  @override
  Future<void> logout() async => calls.add('logout');
}

Future<_Auth> _show(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final auth = _Auth();
  await tester.pumpWidget(ProviderScope(
    overrides: [authProvider.overrideWith(() => auth)],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const VerifyEmailScreen(email: 'ada@uni.edu.ng'),
    ),
  ));
  await tester.pumpAndSettle();
  return auth;
}

/// The resend wait ticks every second; run it out so no timer outlives the test.
Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 31));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a full code submits itself; nothing is sent before that', (tester) async {
    final auth = await _show(tester);
    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    expect(auth.calls, isEmpty);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(auth.calls, ['verify:123456']);
    await _finish(tester);
  });

  testWidgets('a wrong code: says so, clears the boxes for another try', (tester) async {
    final auth = await _show(tester);
    await tester.enterText(find.byType(TextField), '999999');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(auth.calls, ['verify:999999']);
    expect(find.text('That code is incorrect or has expired.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue, reason: 'keyboard stays up for the retry');
    await _finish(tester);
  });

  testWidgets('pasting a code with spaces or dashes keeps only the digits', (tester) async {
    final auth = await _show(tester);
    await tester.enterText(find.byType(TextField), '123-456');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(auth.calls, ['verify:123456']);
    await _finish(tester);
  });

  testWidgets('resend waits 30 seconds; a wrong address can sign out', (tester) async {
    final auth = await _show(tester);
    expect(find.text('Resend code in 30s'), findsOneWidget);
    await tester.tap(find.textContaining('Sign out and start again', findRichText: true));
    await tester.pump();
    expect(auth.calls, ['logout']);
    await _finish(tester);
    expect(find.text('Resend code'), findsOneWidget);
  });
}
