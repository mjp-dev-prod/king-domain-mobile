import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/screens/onboarding/forgot_password_screen.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth({this.resetError});

  final String? resetError;
  final requested = <String>[];
  Map<String, String>? resetWith;

  @override
  AuthState build() => const AuthState(loading: false);

  @override
  Future<void> requestPasswordReset(String email) async => requested.add(email);

  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    if (resetError != null) throw ApiException(resetError!, 400);
    resetWith = {'email': email, 'code': code, 'newPassword': newPassword};
  }
}

/// Mirrors LoginScreen: opens ForgotPasswordScreen and shows what it popped with.
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String result = 'none';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('result: $result'),
        ElevatedButton(
          onPressed: () async {
            final r = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen(initialEmail: 'ada@uni.edu.ng')),
            );
            setState(() => result = '$r');
          },
          child: const Text('open'),
        ),
      ],
    ),
  );
}

Future<_FakeAuth> _toResetScreen(WidgetTester tester, {String? resetError}) async {
  final auth = _FakeAuth(resetError: resetError);
  await tester.pumpWidget(ProviderScope(
    overrides: [authProvider.overrideWith(() => auth)],
    child: const MaterialApp(home: _Host()),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.arrow_forward));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _fill(WidgetTester tester, {required String code, required String password, required String confirm}) async {
  await tester.enterText(find.widgetWithText(TextFormField, '6-digit code'), code);
  await tester.enterText(find.widgetWithText(TextFormField, 'New password'), password);
  await tester.enterText(find.widgetWithText(TextFormField, 'Confirm new password'), confirm);
  final button = find.widgetWithText(ElevatedButton, 'Reset password');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('requesting a code sends the email and moves to code entry', (tester) async {
    final auth = await _toResetScreen(tester);

    expect(auth.requested, ['ada@uni.edu.ng']);
    expect(find.text('Enter your code'), findsOneWidget);
    expect(find.textContaining('ada@uni.edu.ng'), findsOneWidget);
  });

  testWidgets('mismatched passwords are caught before calling the server', (tester) async {
    final auth = await _toResetScreen(tester);

    await _fill(tester, code: '123456', password: 'NewPassw0rd', confirm: 'Different1');

    expect(find.text('Passwords don\'t match.'), findsOneWidget);
    expect(auth.resetWith, isNull);
  });

  testWidgets('successful reset returns to sign-in reporting success', (tester) async {
    final auth = await _toResetScreen(tester);

    await _fill(tester, code: '123456', password: 'NewPassw0rd', confirm: 'NewPassw0rd');

    expect(auth.resetWith, {'email': 'ada@uni.edu.ng', 'code': '123456', 'newPassword': 'NewPassw0rd'});
    expect(find.text('result: true'), findsOneWidget);
  });

  testWidgets('wrong or expired code shows the server message and stays put', (tester) async {
    await _toResetScreen(tester, resetError: 'That code is incorrect or has expired.');

    await _fill(tester, code: '000000', password: 'NewPassw0rd', confirm: 'NewPassw0rd');

    expect(find.text('That code is incorrect or has expired.'), findsOneWidget);
    expect(find.text('Enter your code'), findsOneWidget);
  });

  testWidgets('resend is locked for the cooldown, then sends again', (tester) async {
    final auth = await _toResetScreen(tester);

    final locked = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Resend code in 60s'));
    expect(locked.onPressed, isNull);

    await tester.pump(const Duration(seconds: 61));
    final resend = find.widgetWithText(TextButton, 'Resend code');
    await tester.ensureVisible(resend);
    await tester.tap(resend);
    await tester.pumpAndSettle();

    expect(auth.requested, ['ada@uni.edu.ng', 'ada@uni.edu.ng']);
  });
}
