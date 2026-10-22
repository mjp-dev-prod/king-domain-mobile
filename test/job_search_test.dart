import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/jobs/feed_filter.dart';
import 'package:king_domain/presentation/screens/jobs/job_feed_screen.dart';

final _now = DateTime.now();

Job _job(
  String id, {
  String title = 'A job',
  String category = 'Design & creative',
  String description = 'Some description.',
  String client = 'Chinedu',
  double budget = 10000,
  int? days = 5,
  Duration age = const Duration(hours: 1),
}) => Job(
  id: id,
  title: title,
  category: category,
  description: description,
  budget: budget,
  clientId: 'c1',
  clientName: client,
  postedAt: _now.subtract(age),
  deliveryDays: days,
);

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    loading: false,
    user: AuthUser(id: 't1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true),
  );
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(
    headline: 'h',
    bio: 'b',
    skillCategories: ['Design & creative'],
    proofItems: [ProofItem(id: 'p1', category: 'Design & creative', title: 'Work', status: ProofReviewStatus.verified)],
  );
}

class _Jobs extends JobsNotifier {
  _Jobs(this.jobs);
  final List<Job> jobs;
  @override
  Future<List<Job>> build() async => jobs;
}

void main() {
  group('search', () {
    final jobs = [
      _job('logo', title: 'Logo and brand kit', description: 'For a campus cafe.'),
      _job('menu', title: 'Menu design', client: 'Mama\'s Kitchen', description: 'A4 menu with photos.'),
      _job('app', title: 'Fix checkout bugs', category: 'Software & tech', description: 'Flutter shop app.'),
    ];
    List<String> ids(String q) => filterAndSortJobs(jobs, query: q).map((j) => j.id).toList();

    test('no query keeps every job', () => expect(ids(''), unorderedEquals(['logo', 'menu', 'app'])));
    test('blank spaces count as no query', () => expect(ids('   '), unorderedEquals(['logo', 'menu', 'app'])));
    test('matches the title, ignoring case', () => expect(ids('LOGO'), ['logo']));
    test('matches the description', () => expect(ids('flutter'), ['app']));
    test('matches the category', () => expect(ids('software'), ['app']));
    test('matches the client name', () => expect(ids('mama'), ['menu']));
    test('every word must match, in any order and any field', () {
      expect(ids('menu kitchen'), ['menu']);
      expect(ids('kitchen menu'), ['menu']);
      expect(ids('menu flutter'), isEmpty);
    });
    test('extra spaces between words do not matter', () => expect(ids('  menu    design '), ['menu']));
  });

  group('sort', () {
    final jobs = [
      _job('old-cheap', budget: 5000, days: 10, age: const Duration(days: 5)),
      _job('new-mid', budget: 20000, days: 3, age: const Duration(hours: 1)),
      _job('mid-rich', budget: 90000, days: null, age: const Duration(days: 2)),
    ];
    List<String> order(FeedSort s) => filterAndSortJobs(jobs, sort: s).map((j) => j.id).toList();

    test('newest first by default', () => expect(order(FeedSort.newest), ['new-mid', 'mid-rich', 'old-cheap']));
    test('highest budget first', () => expect(order(FeedSort.budgetHigh), ['mid-rich', 'new-mid', 'old-cheap']));
    test('lowest budget first', () => expect(order(FeedSort.budgetLow), ['old-cheap', 'new-mid', 'mid-rich']));
    test('fastest delivery first, jobs with no delivery time last', () => expect(order(FeedSort.fastest), ['new-mid', 'old-cheap', 'mid-rich']));
    test('equal budgets fall back to newest', () {
      final tied = [_job('a', budget: 1000, age: const Duration(days: 3)), _job('b', budget: 1000, age: const Duration(hours: 2))];
      expect(filterAndSortJobs(tied, sort: FeedSort.budgetHigh).map((j) => j.id), ['b', 'a']);
    });
    test('does not change the list it was given', () {
      final copy = [...jobs];
      filterAndSortJobs(jobs, sort: FeedSort.budgetHigh);
      expect(jobs.map((j) => j.id), copy.map((j) => j.id));
    });
  });

  group('can apply only', () {
    final jobs = [_job('design', category: 'Design & creative'), _job('tech', category: 'Software & tech')];
    test('keeps only the jobs the callback says the talent can apply to', () {
      final r = filterAndSortJobs(jobs, canApplyOnly: true, canApply: (j) => j.category == 'Design & creative');
      expect(r.map((j) => j.id), ['design']);
    });
    test('off means everything, whatever the callback says', () {
      expect(filterAndSortJobs(jobs, canApply: (_) => false), hasLength(2));
    });
    test('on with no callback keeps nothing rather than pretending', () {
      expect(filterAndSortJobs(jobs, canApplyOnly: true), isEmpty);
    });
    test('combines with search and sort', () {
      final many = [
        _job('d1', title: 'Poster', budget: 1000),
        _job('d2', title: 'Poster two', budget: 5000),
        _job('t1', title: 'Poster tech', category: 'Software & tech', budget: 9000),
      ];
      final r = filterAndSortJobs(many, query: 'poster', canApplyOnly: true, canApply: (j) => j.category == 'Design & creative', sort: FeedSort.budgetHigh);
      expect(r.map((j) => j.id), ['d2', 'd1']);
    });
  });

  group('the feed screen', () {
    Future<void> show(WidgetTester tester, List<Job> jobs) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          jobsProvider.overrideWith(() => _Jobs(jobs)),
          talentProfileProvider.overrideWith(_Profile.new),
        ],
        child: MaterialApp(
          theme: AppTheme.theme,
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
          home: const Scaffold(body: JobFeedScreen()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    double y(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

    testWidgets('typing narrows the list; clearing brings it back', (tester) async {
      await show(tester, [_job('1', title: 'Logo and brand kit'), _job('2', title: 'Menu design'), _job('3', title: 'Fix bugs')]);
      expect(find.text('Menu design'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'logo');
      await tester.pumpAndSettle();
      expect(find.text('Logo and brand kit'), findsOneWidget);
      expect(find.text('Menu design'), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Menu design'), findsOneWidget);
      expect(find.text('Fix bugs'), findsOneWidget);
    });

    testWidgets('no match says why and Clear filters brings everything back', (tester) async {
      await show(tester, [_job('1', title: 'Logo and brand kit')]);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No jobs match'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Logo and brand kit'), findsOneWidget);
      expect(find.text('No jobs match'), findsNothing);
    });

    testWidgets('sorting by budget reorders the cards', (tester) async {
      await show(tester, [_job('1', title: 'Small job', budget: 1000), _job('2', title: 'Big job', budget: 90000, age: const Duration(days: 3))]);
      expect(y(tester, 'Small job') < y(tester, 'Big job'), isTrue, reason: 'newest first by default');
      await tester.tap(find.byTooltip('Sort jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highest budget'));
      await tester.pumpAndSettle();
      expect(y(tester, 'Big job') < y(tester, 'Small job'), isTrue);
    });

    testWidgets('the can-apply switch hides jobs in categories the talent is not verified for, and turns off again', (tester) async {
      await show(tester, [_job('1', title: 'Design gig'), _job('2', title: 'Tech gig', category: 'Software & tech')]);
      expect(find.text('Tech gig'), findsOneWidget);
      await tester.tap(find.byTooltip('Only jobs I can apply for'));
      await tester.pumpAndSettle();
      expect(find.text('Design gig'), findsOneWidget);
      expect(find.text('Tech gig'), findsNothing);
      await tester.tap(find.byTooltip('Only jobs I can apply for'));
      await tester.pumpAndSettle();
      expect(find.text('Tech gig'), findsOneWidget);
    });

    testWidgets('the category chips are all still reachable on a 360-wide screen start', (tester) async {
      await show(tester, [_job('1', title: 'Design gig'), _job('2', title: 'Tech gig', category: 'Software & tech')]);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Software & tech'));
      await tester.pumpAndSettle();
      expect(find.text('Design gig'), findsNothing);
      expect(find.text('Tech gig'), findsOneWidget);
    });
  });
}
