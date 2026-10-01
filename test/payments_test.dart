import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/formatting/currency.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/jobs/job_detail_screen.dart';
import 'package:king_domain/presentation/screens/payments/fund_contract_screen.dart';
import 'package:king_domain/presentation/screens/payments/payout_account_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

final _awarded = Job(
  id: 'j1',
  title: 'Logo for a campus startup',
  category: 'Design & creative',
  description: 'd',
  budget: 5000,
  clientId: 'c1',
  clientName: 'Client',
  postedAt: DateTime(2026, 10, 1),
  contractStatus: ContractStatus.awaitingPayment,
  platformFeeAmount: 500,
);

class _FakeJobs extends JobsNotifier {
  _FakeJobs({this.checkoutUrl = 'https://checkout.paystack.com/test123', this.verifyResult = 'success'});

  final String? checkoutUrl;
  final String verifyResult;
  int fundCalls = 0;

  @override
  Future<List<Job>> build() async => [_awarded];

  void _markFunded() => state = AsyncData([_awarded.copyWith(contractStatus: ContractStatus.funded)]);

  @override
  Future<String?> startFunding(String jobId) async {
    fundCalls++;
    if (checkoutUrl == null) _markFunded();
    return checkoutUrl;
  }

  @override
  Future<String> verifyPayment(String jobId) async {
    if (verifyResult == 'success') _markFunded();
    return verifyResult;
  }
}

class _FakeLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  _FakeLauncher({this.succeed = true});

  final bool succeed;
  String? launchedUrl;
  PreferredLaunchMode? launchedMode;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    launchedMode = options.mode;
    return succeed;
  }
}

class _FakeProfile extends TalentProfileNotifier {
  _FakeProfile({this.resolveError});

  final String? resolveError;
  String? savedAccount;

  @override
  Future<TalentProfile> build() async => const TalentProfile(headline: 'h', bio: 'b');

  @override
  Future<String> resolvePayoutAccount({required String accountNumber, required String bankCode}) async {
    if (resolveError != null) throw ApiException(resolveError!, 400);
    return 'ADA OBI';
  }

  @override
  Future<void> savePayoutAccount({required String accountNumber, required String bankCode}) async {
    savedAccount = '$bankCode:$accountNumber';
    state = const AsyncData(
      TalentProfile(
        headline: 'h',
        bio: 'b',
        payoutAccount: PayoutAccount(bankName: 'GTBank', accountName: 'ADA OBI', accountNumberLast4: '6789'),
      ),
    );
  }
}

class _StaticJobs extends JobsNotifier {
  _StaticJobs(this.jobs);
  final List<Job> jobs;

  @override
  Future<List<Job>> build() async => jobs;
}

class _StaticProfile extends TalentProfileNotifier {
  _StaticProfile(this.profile);
  final TalentProfile profile;

  @override
  Future<TalentProfile> build() async => profile;
}

Widget _host(Widget screen, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('FundContractScreen', () {
    testWidgets('shows budget, 10% fee and total the client pays', (tester) async {
      await tester.pumpWidget(_host(const FundContractScreen(jobId: 'j1'), [jobsProvider.overrideWith(_FakeJobs.new)]));
      await _open(tester);

      expect(find.text(formatNaira(5000)), findsOneWidget);
      expect(find.text(formatNaira(500)), findsOneWidget);
      expect(find.text(formatNaira(5500)), findsOneWidget);
      expect(find.text('Pay ${formatNaira(5500)}'), findsOneWidget);
    });

    testWidgets('opens Paystack checkout in the in-app browser, then verify flips to confirmed', (tester) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      await tester.pumpWidget(_host(const FundContractScreen(jobId: 'j1'), [jobsProvider.overrideWith(_FakeJobs.new)]));
      await _open(tester);

      await tester.tap(find.text('Pay ${formatNaira(5500)}'));
      await tester.pumpAndSettle();

      expect(launcher.launchedUrl, 'https://checkout.paystack.com/test123');
      expect(launcher.launchedMode, PreferredLaunchMode.inAppBrowserView);
      expect(find.text('I\'ve paid — check status'), findsOneWidget);

      await tester.tap(find.text('I\'ve paid — check status'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Payment confirmed'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('unconfirmed payment keeps the client on the waiting state with guidance', (tester) async {
      UrlLauncherPlatform.instance = _FakeLauncher();
      await tester.pumpWidget(_host(
        const FundContractScreen(jobId: 'j1'),
        [jobsProvider.overrideWith(() => _FakeJobs(verifyResult: 'abandoned'))],
      ));
      await _open(tester);

      await tester.tap(find.text('Pay ${formatNaira(5500)}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I\'ve paid — check status'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Payment not completed yet'), findsOneWidget);
      expect(find.textContaining('Payment confirmed'), findsNothing);
      expect(find.text('Reopen checkout'), findsOneWidget);
    });

    testWidgets('previous checkout already paid: no second checkout is opened', (tester) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      await tester.pumpWidget(_host(
        const FundContractScreen(jobId: 'j1'),
        [jobsProvider.overrideWith(() => _FakeJobs(checkoutUrl: null))],
      ));
      await _open(tester);

      await tester.tap(find.text('Pay ${formatNaira(5500)}'));
      await tester.pumpAndSettle();

      expect(launcher.launchedUrl, isNull);
      expect(find.textContaining('Payment confirmed'), findsOneWidget);
    });

    testWidgets('browser fails to open: error shown, client can retry', (tester) async {
      UrlLauncherPlatform.instance = _FakeLauncher(succeed: false);
      await tester.pumpWidget(_host(const FundContractScreen(jobId: 'j1'), [jobsProvider.overrideWith(_FakeJobs.new)]));
      await _open(tester);

      await tester.tap(find.text('Pay ${formatNaira(5500)}'));
      await tester.pumpAndSettle();

      expect(find.text('Could not open the payment page.'), findsOneWidget);
      expect(find.text('Pay ${formatNaira(5500)}'), findsOneWidget);
    });
  });

  group('JobDetailScreen payout gate', () {
    final openJob = Job(
      id: 'j2',
      title: 'Poster design',
      category: 'Design & creative',
      description: 'd',
      budget: 3000,
      clientId: 'c1',
      clientName: 'Client',
      postedAt: DateTime(2026, 10, 1),
    );
    const verifiedProof = [ProofItem(id: 'p1', category: 'Design & creative', title: 'Portfolio', status: ProofReviewStatus.verified)];

    Future<ElevatedButton> applyButton(WidgetTester tester, TalentProfile profile) async {
      await tester.pumpWidget(_host(const JobDetailScreen(jobId: 'j2'), [
        jobsProvider.overrideWith(() => _StaticJobs([openJob])),
        talentProfileProvider.overrideWith(() => _StaticProfile(profile)),
      ]));
      await _open(tester);
      return tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
    }

    testWidgets('verified talent without a payout account cannot apply', (tester) async {
      final button = await applyButton(tester, const TalentProfile(proofItems: verifiedProof));
      expect(button.onPressed, isNull);
      expect(find.text('Payout account required'), findsOneWidget);
      expect(find.textContaining('Add a payout account to apply'), findsOneWidget);
    });

    testWidgets('verified talent with a payout account can apply', (tester) async {
      final button = await applyButton(
        tester,
        const TalentProfile(
          proofItems: verifiedProof,
          payoutAccount: PayoutAccount(accountName: 'ADA OBI', accountNumberLast4: '6789'),
        ),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text('Apply for this job'), findsOneWidget);
    });
  });

  group('PayoutAccountScreen', () {
    final banks = banksProvider.overrideWith(
      (ref) async => const [Bank(name: 'Access Bank', code: '044'), Bank(name: 'GTBank', code: '058')],
    );

    Future<void> fillIn(WidgetTester tester) async {
      await tester.tap(find.text('Bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GTBank'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Account number'), '0123456789');
      await tester.pumpAndSettle();
    }

    testWidgets('looks up the account holder, then saves only after the talent sees the name', (tester) async {
      final profile = _FakeProfile();
      await tester.pumpWidget(_host(const PayoutAccountScreen(), [banks, talentProfileProvider.overrideWith(() => profile)]));
      await _open(tester);

      final save = find.widgetWithText(ElevatedButton, 'That\'s me — save account');
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);

      await fillIn(tester);

      expect(find.text('ADA OBI'), findsOneWidget);
      expect(profile.savedAccount, isNull);
      expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);

      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(profile.savedAccount, '058:0123456789');
      expect(find.text('Payout account saved.'), findsOneWidget);
    });

    testWidgets('unresolvable account shows the error and keeps save disabled', (tester) async {
      await tester.pumpWidget(_host(
        const PayoutAccountScreen(),
        [banks, talentProfileProvider.overrideWith(() => _FakeProfile(resolveError: 'Could not resolve account name.'))],
      ));
      await _open(tester);

      await fillIn(tester);

      expect(find.text('Could not resolve account name.'), findsOneWidget);
      final save = find.widgetWithText(ElevatedButton, 'That\'s me — save account');
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
    });
  });
}
