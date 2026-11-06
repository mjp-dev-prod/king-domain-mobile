import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/formatting/about_amount.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/contract_extras.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/providers/contract_extras_provider.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/screens/contracts/drafts_screen.dart';
import 'package:king_domain/presentation/screens/contracts/receipt_screen.dart';
import 'package:king_domain/presentation/screens/contracts/start_proof_screen.dart';

final _now = DateTime.now();

Job _job({String? skillKey = 'graphic-design', ContractStatus status = ContractStatus.inProgress, String? proofStatus}) => Job(
  id: 'j1',
  title: 'Logo and brand kit',
  category: 'Design & creative',
  description: 'd',
  budget: 10000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(const Duration(days: 5)),
  contractStatus: status,
  skillKey: skillKey,
  startProofStatus: proofStatus,
);

class _Jobs extends JobsNotifier {
  final Job job;
  _Jobs(this.job);
  @override
  Future<List<Job>> build() async => [job];
}

class _Actions extends ContractExtrasActions {
  _Actions(super.ref);
  static final calls = <String>[];
  static ApiException? failNext;

  void _maybeFail() {
    final e = failNext;
    failNext = null;
    if (e != null) throw e;
  }

  @override
  Future<void> submitProof(String jobId) async {
    _maybeFail();
    calls.add('submit');
  }

  @override
  Future<void> acceptProof(String jobId) async {
    _maybeFail();
    calls.add('accept');
  }

  @override
  Future<void> objectToProof(String jobId, {required String reasonCode, required String note}) async => calls.add('object:$reasonCode:$note');

  @override
  Future<void> saveText(String jobId, String fieldKey, String text) async => calls.add('text:$fieldKey:$text');
}

class _Currency extends DisplayCurrencyNotifier {
  final String value;
  _Currency(this.value);
  @override
  Future<String> build() async => value;
}

const _reasons = [ObjectionReason('missing_part', 'A required part is missing'), ObjectionReason('wrong_format', 'It is not in the agreed format')];

ProofField _field(String key, String label, String kind, int min, int max, [int items = 0]) => ProofField(
  key: key,
  label: label,
  kind: kind,
  min: min,
  max: max,
  items: [for (var i = 0; i < items; i++) ProofItem(id: '$key$i', name: '$key$i.png', contentType: 'image/png', sizeBytes: 2048, text: kind == 'text' ? 'An outline that is long enough.' : null)],
);

StartProof _proof({String? status, List<ProofField>? fields, bool ready = false, List<String> missing = const [], ProofObjection? objection, DateTime? dueAt}) => StartProof(
  required: true,
  status: status,
  round: 0,
  submittedAt: status == null ? null : _now,
  dueAt: dueAt,
  acceptedAt: null,
  objection: objection,
  upfrontAmount: 2000,
  upfrontPaidAt: null,
  fields: fields ?? [_field('concepts', 'Two or three concept directions', 'files', 2, 3, 1), _field('moodboard', 'A moodboard', 'image', 1, 1)],
  missing: missing,
  readyToSend: ready,
  objectionReasons: _reasons,
  uploadsAvailable: true,
  currency: 'NGN',
);

Future<void> _show(WidgetTester tester, Widget screen, {StartProof? proof, Job? job, String display = 'NGN', double? rate}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  _Actions.calls.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      jobsProvider.overrideWith(() => _Jobs(job ?? _job())),
      if (proof != null) startProofProvider('j1').overrideWith((ref) async => proof),
      displayCurrencyProvider.overrideWith(() => _Currency(display)),
      fxRateProvider.overrideWith((ref) async => FxRate(ngnPerUsd: rate)),
      contractExtrasActionsProvider.overrideWith((ref) => _Actions(ref)),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: screen,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  group('about amounts', () {
    test('a naira price is shown as about dollars for someone who thinks in dollars', () {
      expect(aboutAmount(15000, currency: 'NGN', display: 'USD', ngnPerUsd: 1500), 'about \$10');
      expect(aboutAmount(20000, currency: 'NGN', display: 'USD', ngnPerUsd: 1500), 'about \$13.33');
    });

    test('a dollar price is shown as about naira the other way', () {
      expect(aboutAmount(10, currency: 'USD', display: 'NGN', ngnPerUsd: 1500), 'about ₦15,000');
    });

    test('nothing is shown for the same currency or when no rate is set', () {
      expect(aboutAmount(100, currency: 'NGN', display: 'NGN', ngnPerUsd: 1500), isNull);
      expect(aboutAmount(100, currency: 'NGN', display: 'USD', ngnPerUsd: null), isNull);
      expect(aboutAmount(100, currency: 'NGN', display: 'USD', ngnPerUsd: 0), isNull);
    });
  });

  group('models', () {
    test('a start proof reads what is asked for, what is there and what is missing', () {
      final p = StartProof.fromJson({
        'startProof': {
          'required': true,
          'status': 'redo',
          'round': 1,
          'upfrontAmount': 2000,
          'currency': 'NGN',
          'readyToSend': false,
          'uploadsAvailable': true,
          'missing': [
            {'key': 'moodboard', 'label': 'A moodboard', 'problem': 'A moodboard: add one'},
          ],
          'objection': {'reasonCode': 'wrong_format', 'label': 'It is not in the agreed format', 'note': 'One screenshot only.'},
          'objectionReasons': [
            {'code': 'missing_part', 'label': 'A required part is missing'},
          ],
          'fields': [
            {'key': 'concepts', 'label': 'Concepts', 'kind': 'files', 'min': 2, 'max': 3, 'items': []},
          ],
        },
      });
      expect(p.editable, isTrue, reason: 'sent back, so the talent can fix it');
      expect(p.round, 1);
      expect(p.missing, ['A moodboard: add one']);
      expect(p.objection?.note, 'One screenshot only.');
      expect(p.fields.single.countWords, '2 to 3');
      expect(p.fields.single.done, isFalse);
      expect(_proof(status: 'submitted').editable, isFalse);
    });

    test('a job owes its start proof only while paid, worked on, and not yet accepted', () {
      expect(_job().startProofOwed, isTrue);
      expect(_job(status: ContractStatus.funded).startProofOwed, isTrue);
      expect(_job(proofStatus: 'submitted').startProofOwed, isTrue);
      expect(_job(proofStatus: 'accepted').startProofOwed, isFalse);
      expect(_job(status: ContractStatus.submitted).startProofOwed, isFalse);
      expect(_job(skillKey: null).startProofOwed, isFalse, reason: 'older jobs have no start proof');
    });

    test('a receipt hides payouts from the client and shows them to the talent', () {
      final base = {
        'jobTitle': 'Logo',
        'service': 'Graphic design: Logo',
        'currency': 'NGN',
        'price': 10000,
        'platformFee': 1000,
        'totalPaidByClient': 11000,
        'status': 'inProgress',
        'client': {'name': 'Chinedu'},
      };
      final asClient = Receipt.fromJson({'viewer': 'client', 'receipt': base});
      expect(asClient.hasPayouts, isFalse);
      final asTalent = Receipt.fromJson({
        'viewer': 'talent',
        'receipt': {
          ...base,
          'payouts': {
            'upfront': {'amount': 2000, 'paidAt': _now.toIso8601String(), 'reference': 'kd_upfront_x'},
            'final': null,
          },
        },
      });
      expect(asTalent.hasPayouts, isTrue);
      expect(asTalent.upfront?.amount, 2000);
      expect(asTalent.finalPayout, isNull);
    });
  });

  group('the talent builds the start proof', () {
    testWidgets('shows every part, says what is missing, and cannot send until it is complete', (tester) async {
      await _show(tester, const StartProofScreen(jobId: 'j1', forClient: false), proof: _proof(missing: ['A moodboard: add one']));

      expect(find.text('Start proof'), findsOneWidget);
      expect(find.text('Two or three concept directions'), findsOneWidget);
      expect(find.text('A moodboard'), findsOneWidget);
      expect(find.textContaining('Show Chinedu you\'ve started'), findsOneWidget);
      expect(find.textContaining('Still to add: A moodboard: add one'), findsOneWidget);
      await tester.tap(find.text('Send the start proof'));
      await tester.pumpAndSettle();
      expect(_Actions.calls, isEmpty, reason: 'disabled while a part is missing');
    });

    testWidgets('a complete proof can be sent, and a refusal is shown rather than swallowed', (tester) async {
      await _show(tester, const StartProofScreen(jobId: 'j1', forClient: false), proof: _proof(ready: true));

      _Actions.failNext = ApiException('Still to add: a moodboard.', 400);
      await tester.tap(find.text('Send the start proof'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Still to add: a moodboard.'), findsOneWidget);
      expect(_Actions.calls, isEmpty);
      await _drainToasts(tester);

      await tester.tap(find.text('Send the start proof'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['submit']);
      await _drainToasts(tester);
    });

    testWidgets('a typed part opens a sheet that checks the length before saving', (tester) async {
      await _show(
        tester,
        const StartProofScreen(jobId: 'j1', forClient: false),
        proof: _proof(fields: [_field('outline', 'An outline of the first page', 'text', 1, 1)]),
      );

      await tester.tap(find.text('Write it'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'too short');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Write at least 20 characters.'), findsOneWidget);
      expect(_Actions.calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'A hero, three offers and a footer.');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['text:outline:A hero, three offers and a footer.']);
    });

    testWidgets('once sent it is read-only and says the client has 24 hours', (tester) async {
      await _show(
        tester,
        const StartProofScreen(jobId: 'j1', forClient: false),
        proof: _proof(status: 'submitted', dueAt: _now.add(const Duration(hours: 20)), fields: [_field('moodboard', 'A moodboard', 'image', 1, 1, 1)]),
      );

      expect(find.text('With the client'), findsOneWidget);
      expect(find.textContaining('If they say nothing, it counts as accepted'), findsOneWidget);
      expect(find.text('Send the start proof'), findsNothing);
      expect(find.text('Add'), findsNothing);
    });

    testWidgets('sent back: shows the point that stood and lets the talent send again', (tester) async {
      await _show(
        tester,
        const StartProofScreen(jobId: 'j1', forClient: false),
        proof: _proof(status: 'redo', ready: false, objection: const ProofObjection(code: 'wrong_format', label: 'It is not in the agreed format', note: 'The moodboard is one screenshot.')),
      );

      expect(find.text('Your start proof needs another go'), findsOneWidget);
      expect(find.textContaining('The moodboard is one screenshot.'), findsOneWidget);
      expect(find.text('Send it again'), findsOneWidget);
    });

    testWidgets('accepted: says the 20% is on its way', (tester) async {
      await _show(tester, const StartProofScreen(jobId: 'j1', forClient: false), proof: _proof(status: 'accepted'));
      expect(find.textContaining('₦2,000 is on its way'), findsOneWidget);
      expect(find.text('Send the start proof'), findsNothing);
    });

    testWidgets('a dollar reader sees the naira 20% marked about', (tester) async {
      await _show(tester, const StartProofScreen(jobId: 'j1', forClient: false), proof: _proof(), display: 'USD', rate: 1000);
      expect(find.text('about \$2'), findsOneWidget);
    });
  });

  group('the client answers the start proof', () {
    testWidgets('accepting pays the 20%', (tester) async {
      await _show(tester, const StartProofScreen(jobId: 'j1', forClient: true), proof: _proof(status: 'submitted', dueAt: _now.add(const Duration(hours: 20))));

      expect(find.text('Look at the start proof'), findsOneWidget);
      expect(find.textContaining('Quality and taste aren\'t grounds'), findsOneWidget);
      await tester.tap(find.text('Accept · pay ₦2,000'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['accept']);
      await _drainToasts(tester);
    });

    testWidgets('raising a point offers only the checklist, never taste', (tester) async {
      await _show(tester, const StartProofScreen(jobId: 'j1', forClient: true), proof: _proof(status: 'submitted', dueAt: _now.add(const Duration(hours: 20))));

      await tester.tap(find.text('Raise a point'));
      await tester.pumpAndSettle();
      expect(find.text('A required part is missing'), findsOneWidget);
      expect(find.text('It is not in the agreed format'), findsOneWidget);
      expect(find.textContaining('like'), findsNothing);
    });

    testWidgets('while a person checks, the client has nothing to press', (tester) async {
      await _show(
        tester,
        const StartProofScreen(jobId: 'j1', forClient: true),
        proof: _proof(status: 'objected', objection: const ProofObjection(code: 'missing_part', label: 'A required part is missing', note: 'There is no moodboard.')),
      );
      expect(find.text('A person is checking it'), findsOneWidget);
      expect(find.text('Raise a point'), findsNothing);
      expect(find.textContaining('Accept'), findsNothing);
    });
  });

  group('failed to load', () {
    testWidgets('the start proof offers a retry', (tester) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          jobsProvider.overrideWith(() => _Jobs(_job())),
          startProofProvider('j1').overrideWith((ref) async => throw ApiException('nope', 500)),
        ],
        child: MaterialApp(theme: AppTheme.theme, builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: const StartProofScreen(jobId: 'j1', forClient: false)),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Couldn\'t load the start proof'), findsOneWidget);
    });
  });

  group('drafts', () {
    Future<void> showDrafts(WidgetTester tester, {required bool client, DraftList? list, bool canShare = true}) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [draftsProvider('j1').overrideWith((ref) async => list ?? const DraftList(drafts: [], uploadsAvailable: true))],
        child: MaterialApp(
          theme: AppTheme.theme,
          builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!),
          home: DraftsScreen(jobId: 'j1', jobTitle: 'Logo and brand kit', forClient: client, canShare: canShare),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('empty for the talent: says what sharing does, and offers it', (tester) async {
      await showDrafts(tester, client: false);
      expect(find.text('Nothing shared yet'), findsOneWidget);
      expect(find.textContaining('doesn\'t hand anything in or start any clock'), findsOneWidget);
      expect(find.text('Share a draft'), findsOneWidget);
    });

    testWidgets('empty for the client: says nothing is needed from them', (tester) async {
      await showDrafts(tester, client: true);
      expect(find.text('No drafts yet'), findsOneWidget);
      expect(find.textContaining('You don\'t need to do anything with it'), findsOneWidget);
      expect(find.text('Share a draft'), findsNothing);
    });

    testWidgets('a finished job shows the record but no share button', (tester) async {
      await showDrafts(
        tester,
        client: false,
        canShare: false,
        list: DraftList(drafts: [
          DraftShare(id: 'd1', note: 'First pass', createdAt: _now, files: const [DraftFile(name: 'draft.png', contentType: 'image/png', sizeBytes: 3000)]),
        ], uploadsAvailable: true),
      );
      expect(find.textContaining('First pass'), findsOneWidget);
      expect(find.text('draft.png'), findsOneWidget);
      expect(find.text('Share a draft'), findsNothing);
    });

    testWidgets('with storage down, sharing says so instead of failing later', (tester) async {
      await showDrafts(tester, client: false, list: const DraftList(drafts: [], uploadsAvailable: false));
      expect(find.textContaining('Sharing files isn\'t available right now'), findsOneWidget);
    });
  });

  group('receipt', () {
    Receipt receipt({required bool talent}) => Receipt(
      viewer: talent ? 'talent' : 'client',
      jobTitle: 'Logo and brand kit',
      service: 'Graphic design: Logo and brand kit',
      currency: 'NGN',
      price: 10000,
      platformFee: 1000,
      totalPaidByClient: 11000,
      paidAt: _now,
      reference: 'kd_ref_1',
      clientName: 'Chinedu',
      talentName: 'Ada Obi',
      status: 'inProgress',
      upfront: talent ? Payout(amount: 2000, paidAt: _now) : null,
      finalPayout: null,
      hasPayouts: talent,
    );

    Future<void> showReceipt(WidgetTester tester, Receipt r) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          receiptProvider('j1').overrideWith((ref) async => r),
          displayCurrencyProvider.overrideWith(() => _Currency('NGN')),
          fxRateProvider.overrideWith((ref) async => const FxRate()),
        ],
        child: MaterialApp(theme: AppTheme.theme, builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: const ReceiptScreen(jobId: 'j1')),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the client sees what was paid, in full, and no payouts', (tester) async {
      await showReceipt(tester, receipt(talent: false));
      expect(find.text('₦11,000'), findsOneWidget);
      expect(find.text('kd_ref_1'), findsOneWidget);
      expect(find.text('Paid to the talent'), findsNothing);
    });

    testWidgets('the talent also sees the 20% paid and the rest still to come', (tester) async {
      await showReceipt(tester, receipt(talent: true));
      expect(find.text('Paid to the talent'), findsOneWidget);
      expect(find.textContaining('₦2,000'), findsOneWidget);
      expect(find.text('Not paid yet'), findsOneWidget);
    });

    testWidgets('before payment there is no receipt, and it says why', (tester) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [receiptProvider('j1').overrideWith((ref) async => throw ApiException('no', 409, code: 'not_paid'))],
        child: MaterialApp(theme: AppTheme.theme, builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: true), child: w!), home: const ReceiptScreen(jobId: 'j1')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('No receipt yet'), findsOneWidget);
    });
  });
}
