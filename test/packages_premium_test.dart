import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/packages.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/billing_gateway.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/packages_provider.dart';
import 'package:king_domain/presentation/screens/packages/job_questions_section.dart';
import 'package:king_domain/presentation/screens/packages/my_packages_screen.dart';
import 'package:king_domain/presentation/screens/packages/package_browse_screen.dart';
import 'package:king_domain/presentation/screens/packages/package_orders_screen.dart';
import 'package:king_domain/presentation/widgets/kit/premium_sheet.dart';
import 'discovery_test_support.dart';

final _now = DateTime.now();

class _Auth extends AuthNotifier {
  final String role;
  _Auth(this.role);
  @override
  AuthState build() => AuthState(loading: false, user: AuthUser(id: 'u1', email: 'a@b.ng', role: role, fullName: 'Ada Obi', emailVerified: true));
}

class _Gateway implements BillingGateway {
  final BillingProduct? item;
  final bool isAvailable;
  const _Gateway({this.item = const BillingProduct(id: 'kd.question', title: 'Ask a question', price: '₦500'), this.isAvailable = true});
  @override
  Future<bool> available() async => isAvailable;
  @override
  Future<BillingProduct?> product(String productId) async => item;
  @override
  Future<BillingPurchase> buy(String productId, {required String accountId}) async => BillingPurchase(productId: productId, token: 'token');
  @override
  Future<void> complete(BillingPurchase purchase) async {}
}

class _Actions extends PackageActions {
  _Actions(Ref ref) : super(ref);
  static final calls = <String>[];
  static Object? failBuy;
  static ApiException? failNext;

  void _maybeFail() {
    final e = failNext;
    failNext = null;
    if (e != null) throw e;
  }

  @override
  Future<void> buyPremium(String productId, {required String accountId}) async {
    final e = failBuy;
    failBuy = null;
    if (e != null) throw e;
    calls.add('buy:$productId:$accountId');
  }

  @override
  Future<void> setPaused(String id, bool paused) async => calls.add('pause:$id:$paused');
  @override
  Future<void> answerOrder(String orderId, {required bool accept}) async {
    _maybeFail();
    calls.add('answer:$orderId:$accept');
  }

  @override
  Future<void> cancelOrder(String orderId) async => calls.add('cancel:$orderId');
  @override
  Future<void> ask(String jobId, String question) async => calls.add('ask:$question');
  @override
  Future<void> answerQuestion(String jobId, String questionId, String answer) async => calls.add('answerQ:$answer');
}

class _EmptyJobs extends JobsNotifier {
  @override
  Future<List<Job>> build() async => const [];
}

PackageItem _pkg({String tier = 'basic', String status = 'active', PackageTalent? talent}) => PackageItem(
  id: 'p-$tier',
  skillKey: 'graphic-design',
  skillLabel: 'Graphic design',
  tier: tier,
  title: 'Logo pack',
  summary: 'A clean logo with two concepts.',
  price: 20000,
  currency: 'NGN',
  deliveryDays: 5,
  revisions: 2,
  included: 'Two concepts, final files',
  quantity: 2,
  formats: 'PNG, SVG',
  status: status,
  talent: talent,
);

PackageOrderItem _order({String status = 'requested', String id = 'o1', DateTime? due}) => PackageOrderItem(
  id: id,
  status: status,
  title: 'Logo pack',
  price: 20000,
  currency: 'NGN',
  deliveryDays: 5,
  skillLabel: 'Graphic design',
  other: 'Tunde Bello',
  jobId: 'j1',
  note: 'For our cafe opening.',
  answerDueAt: due ?? _now.add(const Duration(hours: 40)),
  createdAt: _now,
);

Future<void> _show(WidgetTester tester, Widget home, {String role = 'talent', List<Override> overrides = const [], BillingGateway gateway = const _Gateway()}) async {
  tester.view.physicalSize = const Size(1080, 2800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  _Actions.calls.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...discoveryStubs(),
      authProvider.overrideWith(() => _Auth(role)),
      jobsProvider.overrideWith(_EmptyJobs.new),
      billingGatewayProvider.overrideWithValue(gateway),
      packageActionsProvider.overrideWith((ref) => _Actions(ref)),
      premiumStatusProvider.overrideWith((ref) async => const PremiumStatus(enforced: true, billingConfigured: true, features: [PremiumFeature(feature: 'pre_apply_question', label: 'Ask', productId: 'kd.question', credits: 0)], rule: 'Premium never buys a better place than anyone else. Nobody on King Domain will ever ask you for money to get or do a job. Premium is optional and is only bought inside the app through Google Play.')),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// A screen that opens the premium sheet and shows what it returned.
class _Opener extends ConsumerStatefulWidget {
  final String? productId;
  const _Opener({this.productId = 'kd.question'});
  @override
  ConsumerState<_Opener> createState() => _OpenerState();
}

class _OpenerState extends ConsumerState<_Opener> {
  String result = 'nothing yet';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      TextButton(
        onPressed: () async {
          final ok = await offerPremium(context, feature: 'pre_apply_question', productId: widget.productId);
          setState(() => result = ok ? 'bought' : 'not bought');
        },
        child: const Text('open'),
      ),
      Text(result),
    ]),
  );
}

void main() {
  group('premium', () {
    testWidgets('says what it does and does not do, the rule, and the price from the store', (tester) async {
      await _show(tester, const _Opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Ask before you apply'), findsOneWidget);
      expect(find.textContaining('doesn\'t put you ahead of anyone'), findsOneWidget);
      expect(find.textContaining('Nobody on King Domain will ever ask you for money'), findsOneWidget);
      expect(find.text('Buy for ₦500'), findsOneWidget);
    });

    testWidgets('buying verifies with the server and hands back to the caller', (tester) async {
      await _show(tester, const _Opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy for ₦500'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['buy:kd.question:u1']);
      expect(find.text('bought'), findsOneWidget);
    });

    testWidgets('backing out of the store leaves the sheet open and charges nothing', (tester) async {
      await _show(tester, const _Opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      _Actions.failBuy = const BillingCancelled();
      await tester.tap(find.text('Buy for ₦500'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Buy for ₦500'), findsOneWidget);
      expect(find.text('bought'), findsNothing);
    });

    testWidgets('a purchase our server could not verify shows the reason, in the sheet', (tester) async {
      await _show(tester, const _Opener());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      _Actions.failBuy = ApiException('Couldn\'t check the purchase with Google Play. Try again in a moment; you won\'t be charged twice.', 502);
      await tester.tap(find.text('Buy for ₦500'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('you won\'t be charged twice'), findsOneWidget);
    });

    testWidgets('with no store on the phone, or no product set up, it says so and offers nothing', (tester) async {
      await _show(tester, const _Opener(), gateway: const _Gateway(isAvailable: false));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Google Play isn\'t available on this phone'), findsOneWidget);
      expect(find.textContaining('Buy for'), findsNothing);
    });

    testWidgets('no product id means buying is not switched on', (tester) async {
      await _show(tester, const _Opener(productId: null));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Buying isn\'t switched on yet'), findsOneWidget);
    });
  });

  group('a talent\'s packages', () {
    testWidgets('without a verified skill, says to get verified first', (tester) async {
      await _show(tester, const MyPackagesScreen(), overrides: [myPackagesProvider.overrideWith((ref) async => const MyPackages(packages: [], skills: [], tiers: ['basic', 'standard', 'premium']))]);
      expect(find.text('Get verified first'), findsOneWidget);
      expect(find.text('Go to your skills'), findsOneWidget);
    });

    testWidgets('shows three tiers per verified skill, one published and two to add, and can pause it', (tester) async {
      await _show(tester, const MyPackagesScreen(), overrides: [
        myPackagesProvider.overrideWith((ref) async => MyPackages(packages: [_pkg()], skills: const [(skillKey: 'graphic-design', label: 'Graphic design')], tiers: const ['basic', 'standard', 'premium'])),
      ]);
      expect(find.text('Basic: Logo pack'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Add a Standard package'), findsOneWidget);
      expect(find.text('Add a Premium package'), findsOneWidget);
      await tester.tap(find.text('Pause it'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['pause:p-basic:true']);
    });

    testWidgets('failed to load offers a retry', (tester) async {
      await _show(tester, const MyPackagesScreen(), overrides: [myPackagesProvider.overrideWith((ref) async => throw ApiException('no', 500))]);
      expect(find.textContaining('Couldn\'t load your packages'), findsOneWidget);
    });
  });

  group('browsing packages', () {
    testWidgets('lists packages with the talent and the price, with no score or rank', (tester) async {
      await _show(tester, const PackageBrowseScreen(), role: 'client', overrides: [
        packageBrowseProvider(null).overrideWith((ref) async => PackagePage(packages: [_pkg(talent: const PackageTalent(id: 't1', fullName: 'Ada Obi', lastActive: 'today'))])),
      ]);
      expect(find.text('Logo pack'), findsOneWidget);
      expect(find.text('₦20,000'), findsOneWidget);
      expect(find.text('Ada Obi'), findsOneWidget);
      expect(find.textContaining('Active today'), findsOneWidget);
      expect(find.textContaining('rank'), findsNothing);
    });

    testWidgets('empty says why and what to do next', (tester) async {
      await _show(tester, const PackageBrowseScreen(), role: 'client', overrides: [packageBrowseProvider(null).overrideWith((ref) async => const PackagePage(packages: []))]);
      expect(find.text('No packages here yet'), findsOneWidget);
      expect(find.textContaining('post the job'), findsOneWidget);
    });
  });

  group('package orders', () {
    testWidgets('a talent sees the clock and can accept or decline', (tester) async {
      await _show(tester, const PackageOrdersScreen(), overrides: [packageOrdersProvider.overrideWith((ref) async => [_order()])]);
      expect(find.textContaining('Waiting · '), findsOneWidget);
      expect(find.text('For Tunde Bello · Graphic design'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['answer:o1:true']);
      await _drain(tester);
    });

    testWidgets('a refusal when accepting is shown', (tester) async {
      await _show(tester, const PackageOrdersScreen(), overrides: [packageOrdersProvider.overrideWith((ref) async => [_order()])]);
      _Actions.failNext = ApiException('Add the bank account you are paid into before you accept.', 400);
      await tester.tap(find.text('Accept'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Add the bank account you are paid into before you accept.'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a client can cancel while it waits, and nothing is charged', (tester) async {
      await _show(tester, const PackageOrdersScreen(), role: 'client', overrides: [packageOrdersProvider.overrideWith((ref) async => [_order()])]);
      expect(find.text('From Tunde Bello · Graphic design'), findsOneWidget);
      await tester.tap(find.text('Cancel this order'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['cancel:o1']);
      await _drain(tester);
    });

    testWidgets('an order nobody answered says so, and the client knows nothing was charged', (tester) async {
      await _show(tester, const PackageOrdersScreen(), role: 'client', overrides: [packageOrdersProvider.overrideWith((ref) async => [_order(status: 'expired')])]);
      expect(find.text('No answer in 48 hours'), findsOneWidget);
      expect(find.textContaining('Nothing was charged'), findsOneWidget);
    });

    testWidgets('an accepted order for the client points at paying', (tester) async {
      await _show(tester, const PackageOrdersScreen(), role: 'client', overrides: [packageOrdersProvider.overrideWith((ref) async => [_order(status: 'accepted')])]);
      expect(find.text('Pay and start'), findsOneWidget);
    });

    testWidgets('no orders yet says what will appear here', (tester) async {
      await _show(tester, const PackageOrdersScreen(), overrides: [packageOrdersProvider.overrideWith((ref) async => const [])]);
      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.textContaining('you have 48 hours to answer'), findsOneWidget);
    });
  });

  group('questions before applying', () {
    Job job({JobApplicationStatus applied = JobApplicationStatus.notApplied}) => Job(
      id: 'j1',
      title: 'Logo',
      category: 'Design & creative',
      description: 'd',
      budget: 10000,
      clientId: 'c1',
      clientName: 'Chinedu',
      postedAt: _now,
      skillKey: 'graphic-design',
      applicationStatus: applied,
    );

    testWidgets('answers are shown to everyone, and a talent who has not applied can ask', (tester) async {
      await _show(tester, Scaffold(body: SingleChildScrollView(child: JobQuestionsSection(job: job(), isClient: false))), overrides: [
        jobQuestionsProvider('j1').overrideWith((ref) async => [JobQuestion(id: 'q1', question: 'Print too?', answer: 'Yes, both.', askedAt: _now)]),
      ]);
      expect(find.text('Print too?'), findsOneWidget);
      expect(find.text('Yes, both.'), findsOneWidget);
      expect(find.text('Ask a question before applying'), findsOneWidget);
    });

    testWidgets('someone who already applied is not offered a question', (tester) async {
      await _show(tester, Scaffold(body: JobQuestionsSection(job: job(applied: JobApplicationStatus.pending), isClient: false)), overrides: [jobQuestionsProvider('j1').overrideWith((ref) async => const <JobQuestion>[])]);
      expect(find.text('Ask a question before applying'), findsNothing);
    });

    testWidgets('with premium on and nothing bought, asking opens the purchase first, then the question', (tester) async {
      await _show(tester, Scaffold(body: SingleChildScrollView(child: JobQuestionsSection(job: job(), isClient: false))), overrides: [jobQuestionsProvider('j1').overrideWith((ref) async => const <JobQuestion>[])]);
      await tester.tap(find.text('Ask a question before applying'));
      await tester.pumpAndSettle();
      expect(find.text('Buy for ₦500'), findsOneWidget);
      await tester.tap(find.text('Buy for ₦500'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Ask the client'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Is the logo for print as well?');
      await tester.pump();
      await tester.tap(find.text('Send the question'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['buy:kd.question:u1', 'ask:Is the logo for print as well?']);
      await _drain(tester);
    });

    testWidgets('a client sees waiting questions and can answer them', (tester) async {
      await _show(tester, Scaffold(body: SingleChildScrollView(child: JobQuestionsSection(job: job(), isClient: true))), role: 'client', overrides: [
        jobQuestionsProvider('j1').overrideWith((ref) async => [JobQuestion(id: 'q1', question: 'Print too?', canAnswer: true, askedAt: _now)]),
      ]);
      expect(find.text('Print too?'), findsOneWidget);
      await tester.tap(find.text('Answer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Yes, both.');
      await tester.pump();
      await tester.tap(find.text('Post the answer'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['answerQ:Yes, both.']);
      await _drain(tester);
    });
  });
}
