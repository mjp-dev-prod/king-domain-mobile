import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/contract_extras_provider.dart';
import 'package:king_domain/presentation/providers/messaging_provider.dart';
import 'package:king_domain/presentation/screens/profile/settings_screen.dart';
import 'discovery_test_support.dart';

class _Auth extends AuthNotifier {
  static bool signedOut = false;
  @override
  AuthState build() => AuthState(loading: false, user: AuthUser(id: 'u1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true));

  // Like the real one, which clears the login without closing any screen pushed on top.
  @override
  Future<void> logout() async => signedOut = true;
}

Future<ProviderContainer> _show(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [authProvider.overrideWith(_Auth.new), displayCurrencyProvider.overrideWith(FakeDisplayCurrency.new)]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const SettingsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('groups settings by what they affect, with the account last', (tester) async {
    await _show(tester);
    expect(find.text('Settings'), findsOneWidget);
    for (final section in ['DISPLAY', 'DATA', 'PRIVACY AND SAFETY', 'ACCOUNT']) {
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(find.text('Money shown in'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Signed in as ada@uni.edu.ng'), findsOneWidget);
  });

  testWidgets('data saver is a switch you can flip from the row or the switch, and it says what it does', (tester) async {
    final container = await _show(tester);
    expect(container.read(dataSaverProvider), isFalse);
    expect(find.textContaining('Photos in messages load as they arrive'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(dataSaverProvider), isTrue);
    expect(find.textContaining('wait until you tap them'), findsOneWidget);
    await tester.tap(find.text('Data saver'));
    await tester.pumpAndSettle();
    expect(container.read(dataSaverProvider), isFalse, reason: 'tapping the row toggles it too');
  });

  testWidgets('signing out from Settings lands on the first screen, with no Back needed', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    _Auth.signedOut = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(_Auth.new), displayCurrencyProvider.overrideWith(FakeDisplayCurrency.new)],
      child: MaterialApp(
        theme: AppTheme.theme,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), child: const Text('First screen'))))),
      ),
    ));
    await tester.tap(find.text('First screen'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(_Auth.signedOut, isTrue);
    expect(find.text('Settings'), findsNothing, reason: 'Settings must not stay up after the login is cleared');
    expect(find.text('First screen'), findsOneWidget);
  });
}
