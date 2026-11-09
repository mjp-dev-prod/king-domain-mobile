import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/app_colors.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/kit/protection_summary.dart';

void main() {
  test('the one-delivery lines state every rule the client agrees to before paying', () {
    final lines = oneDeliveryProtection(price: 50000, fee: 5000, changeRounds: 2, startSharePercent: 20);
    final text = lines.map((l) => '${l.title} ${l.body}').join(' ');
    expect(text, contains('held'));
    expect(text, contains('20%'));
    expect(text, contains('changes up to 2 times'));
    expect(text, contains('full price back'));
    expect(text, contains('5 days'));
  });

  testWidgets('shows the total in gold and every line', (tester) async {
    final lines = oneDeliveryProtection(price: 50000, fee: 5000, changeRounds: 2, startSharePercent: 20);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: Scaffold(body: SingleChildScrollView(child: ProtectionSummary(lines: lines, total: 55000)))));
    final total = tester.widget<Text>(find.text('₦55,000'));
    expect(total.style?.color, AppColors.money);
    for (final l in lines) {
      expect(find.text(l.title), findsOneWidget);
    }
  });
}
