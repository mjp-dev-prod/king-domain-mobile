import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/constants/glossary.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/presentation/widgets/contract/contract_parts.dart';
import 'package:king_domain/presentation/widgets/kit/kd_card.dart';
import 'package:king_domain/presentation/widgets/kit/info_tip.dart';
import 'package:king_domain/presentation/widgets/kit/status_pill.dart';

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: c!),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a notice with a tip shows a small i beside its title, and tapping it explains the term in plain words', (tester) async {
    await _show(tester, const NoticeCard(tone: KdTone.warn, icon: Icons.flag_outlined, title: 'Send your start proof first', body: 'Show them you have started.', tip: Glossary.startProof));
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('What is a start proof?'), findsOneWidget);
    expect(find.textContaining('first 20% of the payment is released'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('What is a start proof?'), findsNothing, reason: 'Got it closes it');
  });

  testWidgets('a notice without a tip has no i', (tester) async {
    await _show(tester, const NoticeCard(tone: KdTone.plain, icon: Icons.info_outline_rounded, title: 'Nothing to explain', body: 'Plain.'));
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget, reason: 'only the notice\'s own icon');
    expect(find.byType(InfoTip), findsNothing);
  });

  testWidgets('a header can carry a tip, and a screen reader hears what it explains', (tester) async {
    final handle = tester.ensureSemantics();
    await _show(tester, ContractHeader(title: 'Start proof', sub: 'Logo', pill: const StatusPill('Waiting'), tip: Glossary.startProof));
    expect(find.bySemanticsLabel('What is a start proof?'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the tap target is finger-sized', (tester) async {
    await _show(tester, const Row(children: [InfoTip(Glossary.proven)]));
    final size = tester.getSize(find.byType(InfoTip));
    expect(size.width, greaterThanOrEqualTo(36));
    expect(size.height, greaterThanOrEqualTo(36));
  });

  group('the glossary stays in plain English', () {
    final all = {
      'verifiedSkill': Glossary.verifiedSkill,
      'firstCheck': Glossary.firstCheck,
      'walkthrough': Glossary.walkthrough,
      'notYet': Glossary.notYet,
      'startProof': Glossary.startProof,
      'changeRounds': Glossary.changeRounds,
      'heldPayment': Glossary.heldPayment,
      'serviceFee': Glossary.serviceFee,
      'proven': Glossary.proven,
      'usageRights': Glossary.usageRights,
      'milestones': Glossary.milestones,
    };
    // Words that make an explanation read like a rule book. If one is needed, the sentence is probably wrong.
    final ruleBook = RegExp(r'\b(breach|terms|unchanged|pursuant|hereby|shall|notwithstanding|aforementioned|penalty|sanction)\b', caseSensitive: false);

    for (final e in all.entries) {
      test(e.key, () {
        expect(e.value.title.endsWith('?') || e.value.title.startsWith('The '), isTrue, reason: 'a question or a plain name');
        expect(ruleBook.hasMatch(e.value.body), isFalse, reason: 'rule-book wording in ${e.key}');
        expect(e.value.body.length, lessThan(460), reason: 'short enough to read in a sheet');
        expect(e.value.body.split('. ').every((s) => s.split(' ').length < 45), isTrue, reason: 'no sentence runs on');
      });
    }
  });
}
