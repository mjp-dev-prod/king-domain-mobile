import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/kd_layout.dart';

Future<void> _show(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: Scaffold(body: Center(child: child))));
  await tester.pump();
}

NetworkImage _networkImage(WidgetTester tester) => tester.widget<Image>(find.byType(Image)).image as NetworkImage;

void main() {
  group('UserAvatar', () {
    testWidgets('without a photo it shows the initials and requests no picture', (tester) async {
      await _show(tester, const UserAvatar(name: 'Ada Obi'));
      expect(find.text('AO'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a single name and an empty name still give something sensible', (tester) async {
      await _show(tester, const UserAvatar(name: 'Ada'));
      expect(find.text('A'), findsOneWidget);
      await _show(tester, const UserAvatar(name: '   '));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('with a photo it asks for exactly that link, and keeps the initials underneath while it loads', (tester) async {
      await _show(tester, const UserAvatar(name: 'Ada Obi', photoUrl: 'https://files.test/avatars/ada.png'));
      expect(_networkImage(tester).url, 'https://files.test/avatars/ada.png');
      expect(find.text('AO'), findsOneWidget);
    });

    testWidgets('a photo that fails to load leaves the initials and raises no error', (tester) async {
      await _show(tester, const UserAvatar(name: 'Ada Obi', photoUrl: 'https://files.test/avatars/missing.png'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('AO'), findsOneWidget);
    });

    testWidgets('an empty link is treated as no photo', (tester) async {
      await _show(tester, const UserAvatar(name: 'Ada Obi', photoUrl: ''));
      expect(find.byType(Image), findsNothing);
      expect(find.text('AO'), findsOneWidget);
    });

    testWidgets('screen readers hear the person\'s name once, not the initials', (tester) async {
      final handle = tester.ensureSemantics();
      await _show(tester, const UserAvatar(name: 'Ada Obi', photoUrl: 'https://files.test/avatars/ada.png'));
      expect(find.bySemanticsLabel('Ada Obi'), findsOneWidget);
      expect(find.bySemanticsLabel('AO'), findsNothing);
      handle.dispose();
    });

    testWidgets('the progress ring still draws around a photo', (tester) async {
      await _show(tester, const UserAvatar(name: 'Ada Obi', photoUrl: 'https://files.test/a.png', size: 84, ring: .5));
      final ring = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      expect(ring.value, .5);
    });

    testWidgets('stays a circle of the size asked for', (tester) async {
      await _show(tester, const UserAvatar(name: 'Ada Obi', photoUrl: 'https://files.test/a.png', size: 46));
      expect(tester.getSize(find.byType(UserAvatar)), const Size(46, 46));
    });
  });
}
