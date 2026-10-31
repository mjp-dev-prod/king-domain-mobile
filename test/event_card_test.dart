import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/app_colors.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/event_card.dart';
import 'package:king_domain/presentation/widgets/kit/kd_button.dart';
import 'package:king_domain/presentation/widgets/kit/kd_card.dart';

Widget _host(Widget child) => MaterialApp(theme: AppTheme.theme, home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  testWidgets('shows the event, its time, the amount in gold and acts from the card', (tester) async {
    var accepted = 0;
    await tester.pumpWidget(_host(EventCard(
      icon: Icons.flag_outlined,
      title: 'Start proof submitted',
      body: 'Rough cut and timeline screenshot.',
      at: DateTime.now().subtract(const Duration(minutes: 5)),
      tone: KdTone.warn,
      amount: '₦10,000',
      actions: [EventCardAction(label: 'Accept', primary: true, onPressed: () async => accepted++)],
    )));
    expect(find.text('Start proof submitted'), findsOneWidget);
    expect(find.text('Rough cut and timeline screenshot.'), findsOneWidget);
    final amount = tester.widget<Text>(find.text('₦10,000'));
    expect(amount.style?.color, AppColors.money);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(accepted, 1);
  });

  testWidgets('a card with no actions shows no buttons', (tester) async {
    await tester.pumpWidget(_host(EventCard(icon: Icons.check, title: 'Approved', at: DateTime.now(), tone: KdTone.ok)));
    expect(find.byType(KdButton), findsNothing);
    expect(find.text('Approved'), findsOneWidget);
  });
}
