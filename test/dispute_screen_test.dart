import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/dispute.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/providers/contract_extras_provider.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/screens/contracts/dispute_screen.dart';

final _now = DateTime.now();

Job _job({ContractStatus status = ContractStatus.inProgress, bool disputeOpen = false}) => Job(
  id: 'j1',
  title: 'Logo and brand kit',
  category: 'Design & creative',
  description: 'd',
  budget: 10000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(const Duration(days: 5)),
  contractStatus: status,
  disputeOpen: disputeOpen,
);

class _Jobs extends JobsNotifier {
  @override
  Future<List<Job>> build() async => [_job()];
}

class _Actions extends ContractExtrasActions {
  _Actions(Ref ref) : super(ref);
  static final calls = <String>[];
  static ApiException? failNext;

  void _maybeFail() {
    final e = failNext;
    failNext = null;
    if (e != null) throw e;
  }

  @override
  Future<void> openDispute(String jobId, {required String problem, required String note}) async {
    _maybeFail();
    calls.add('open:$problem:$note');
  }

  @override
  Future<void> offerWayOut(String jobId, {required String kind, Map<String, dynamic>? params, String? note}) async => calls.add('offer:$kind:${params ?? {}}');

  @override
  Future<void> answerOffer(String jobId, String offerId, {required bool accept}) async => calls.add('answer:$offerId:$accept');

  @override
  Future<void> askTeamToDecide(String jobId) async => calls.add('escalate');

  @override
  Future<double> cancelForRefund(String jobId) async {
    calls.add('cancel');
    return 10000;
  }
}

const _clientProblems = [
  DisputeProblem(code: 'not_as_briefed', label: 'It isn\'t what the brief said', rule: 'The work is judged against the brief.'),
  DisputeProblem(code: 'other_side_silent', label: 'The other person has gone quiet', rule: 'Clocks run.'),
];
const _ways = [DisputeWay(kind: 'more_time', label: 'More time', needs: 'days'), DisputeWay(kind: 'split', label: 'Split what is held', needs: 'talentPercent'), DisputeWay(kind: 'cancel', label: 'Cancel and refund what is held')];

DisputeOffer _offer({bool byMe = false, String status = 'pending', String kind = 'split'}) => DisputeOffer(
  id: 'o1',
  kind: kind,
  label: 'Split what is held',
  description: 'split what is held: 30% to the talent, 70% back to the client',
  note: '',
  status: status,
  byMe: byMe,
  answerDueAt: _now.add(const Duration(hours: 40)),
  createdAt: _now,
);

DisputeView _dispute({String status = 'open', List<DisputeOffer> offers = const [], DisputeRulingView? ruling, bool awaiting = false, String? escalationReason, Map<String, dynamic>? resolution}) => DisputeView(
  id: 'd1',
  status: status,
  problem: 'not_as_briefed',
  problemLabel: 'It isn\'t what the brief said',
  rule: 'The work is judged against the brief.',
  note: 'Three concepts were asked for and one came.',
  filedByRole: 'client',
  filedByMe: true,
  openedAt: _now,
  escalatedAt: status == 'escalated' ? _now : null,
  escalationReason: escalationReason,
  rulingDueAt: status == 'escalated' ? _now.add(const Duration(days: 4)) : null,
  resolvedAt: status == 'resolved' ? _now : null,
  resolution: resolution,
  awaitingApproval: awaiting,
  ruling: ruling,
  offers: offers,
);

DisputeState _state({DisputeView? dispute, bool canFile = true, bool canCancel = false, DateTime? cancelFrom, bool hasAddress = true, String role = 'client', String? heldNote}) => DisputeState(
  role: role,
  dispute: dispute,
  problems: _clientProblems,
  ways: _ways,
  canFile: canFile,
  held: 10000,
  heldNote: heldNote,
  canCancelForRefund: canCancel,
  cancelFrom: cancelFrom,
  maxMoreDays: 5,
  hasAddress: hasAddress,
);

Future<void> _show(WidgetTester tester, DisputeState state) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  _Actions.calls.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      jobsProvider.overrideWith(_Jobs.new),
      disputeProvider('j1').overrideWith((ref) async => state),
      contractExtrasActionsProvider.overrideWith((ref) => _Actions(ref)),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const DisputeScreen(jobId: 'j1', jobTitle: 'Logo and brand kit'),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  group('nothing open', () {
    testWidgets('explains the staircase and lists only the problems that are the person\'s', (tester) async {
      await _show(tester, _state());
      expect(find.text('Most problems are settled between the two of you'), findsOneWidget);
      expect(find.text('What is wrong?'), findsOneWidget);
      expect(find.text('It isn\'t what the brief said'), findsOneWidget);
      expect(find.text('The other person has gone quiet'), findsOneWidget);
    });

    testWidgets('picking a problem shows the rule first, and reporting needs a few words', (tester) async {
      await _show(tester, _state());
      await tester.tap(find.text('It isn\'t what the brief said'));
      await tester.pumpAndSettle();
      expect(find.text('The work is judged against the brief.'), findsOneWidget);
      await tester.tap(find.text('Report it'));
      await tester.pumpAndSettle();
      expect(_Actions.calls, isEmpty, reason: 'disabled until the note is long enough');

      await tester.enterText(find.byType(TextField), 'Three concepts were asked for and one came.');
      await tester.pump();
      await tester.tap(find.text('Report it'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['open:not_as_briefed:Three concepts were asked for and one came.']);
      await _drain(tester);
    });

    testWidgets('a refusal from the server is shown, not swallowed', (tester) async {
      await _show(tester, _state());
      await tester.tap(find.text('The other person has gone quiet'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nothing from them for days now.');
      await tester.pump();
      _Actions.failNext = ApiException('There is already a dispute open on this job.', 409);
      await tester.tap(find.text('Report it'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('There is already a dispute open on this job.'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('three days late with nothing delivered, the client can cancel for a refund after confirming', (tester) async {
      await _show(tester, _state(canCancel: true));
      expect(find.textContaining('Nothing arrived. You can cancel for a refund'), findsOneWidget);
      await tester.tap(find.text('Cancel and refund ₦10,000'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This can\'t be undone'), findsOneWidget);
      expect(_Actions.calls, isEmpty, reason: 'asks first');
      await tester.tap(find.text('Cancel the job'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['cancel']);
      await _drain(tester);
    });

    testWidgets('before that date, says when the option opens', (tester) async {
      await _show(tester, _state(cancelFrom: _now.add(const Duration(days: 2))));
      expect(find.text('If nothing arrives'), findsOneWidget);
    });

    testWidgets('nothing to report once the job is over', (tester) async {
      await _show(tester, _state(canFile: false));
      expect(find.text('Nothing to report right now'), findsOneWidget);
    });
  });

  group('finding a way out', () {
    testWidgets('an offer from the other person can be accepted or declined, with the clock shown', (tester) async {
      await _show(tester, _state(dispute: _dispute(offers: [_offer()])));
      expect(find.textContaining('They offer: split what is held'), findsOneWidget);
      expect(find.textContaining('left'), findsWidgets);
      await tester.tap(find.text('Accept'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['answer:o1:true']);
      await _drain(tester);
    });

    testWidgets('your own offer shows who you are waiting on and what happens on silence', (tester) async {
      await _show(tester, _state(dispute: _dispute(offers: [_offer(byMe: true)])));
      expect(find.textContaining('Your offer:'), findsOneWidget);
      expect(find.textContaining('If they don\'t answer in 48 hours'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Offer a way out'), findsNothing, reason: 'one offer at a time');
    });

    testWidgets('with no offer waiting, the fixed ways out are listed and a split shows the money', (tester) async {
      await _show(tester, _state(dispute: _dispute()));
      expect(find.text('Offer a way out'), findsOneWidget);
      expect(find.text('More time'), findsOneWidget);
      await tester.tap(find.text('Split what is held'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Talent ₦5,000'), findsOneWidget);
      expect(find.textContaining('Client ₦5,000'), findsOneWidget);
      await tester.tap(find.text('Send the offer'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['offer:split:{talentPercent: 50}']);
      await _drain(tester);
    });

    testWidgets('asking the team to decide asks first, and says it is free and final', (tester) async {
      await _show(tester, _state(dispute: _dispute()));
      await tester.tap(find.text('Ask King Domain to decide'));
      await tester.pumpAndSettle();
      expect(find.textContaining('free'), findsWidgets);
      expect(find.textContaining('final'), findsWidgets);
      expect(_Actions.calls, isEmpty);
      await tester.tap(find.text('Yes, ask the team'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['escalate']);
      await _drain(tester);
    });

    testWidgets('asks for an address, once, with the purpose', (tester) async {
      await _show(tester, _state(dispute: _dispute(), hasAddress: false));
      expect(find.text('Tell us where we can reach you'), findsOneWidget);
    });
  });

  group('with the team', () {
    testWidgets('says when the ruling is due and why it came to them', (tester) async {
      await _show(tester, _state(dispute: _dispute(status: 'escalated', escalationReason: 'unanswered')));
      expect(find.textContaining('Ruling due within'), findsOneWidget);
      expect(find.textContaining('an offer wasn\'t answered in 48 hours'), findsOneWidget);
      expect(find.text('Ask King Domain to decide'), findsNothing, reason: 'already with them');
    });

    testWidgets('a ruling waiting for a second person doesn\'t leak the reasons early', (tester) async {
      await _show(tester, _state(dispute: _dispute(status: 'escalated', awaiting: true)));
      expect(find.textContaining('finalising it'), findsOneWidget);
    });
  });

  group('settled', () {
    testWidgets('a ruling shows both people the amounts and the reasons, and says it is final', (tester) async {
      const ruling = DisputeRulingView(outcome: 'split', talentPercent: 30, reasons: 'The brief asked for three directions and one was delivered.', talentAmount: 3000, clientRefund: 7000);
      await _show(tester, _state(canFile: false, dispute: _dispute(status: 'resolved', ruling: ruling, resolution: {'by': 'ruling'})));
      expect(find.text('Ruled: 30% to the talent'), findsOneWidget);
      expect(find.textContaining('₦3,000 to the talent, ₦7,000 back to the client'), findsOneWidget);
      expect(find.textContaining('The brief asked for three directions'), findsOneWidget);
      expect(find.textContaining('Refunds can take 3 to 10 working days'), findsOneWidget);
    });

    testWidgets('an agreement says what was agreed', (tester) async {
      await _show(tester, _state(canFile: false, dispute: _dispute(status: 'resolved', resolution: {'by': 'agreement', 'kind': 'more_time'})));
      expect(find.text('Settled between you'), findsOneWidget);
      expect(find.textContaining('more time'), findsOneWidget);
    });
  });
}
