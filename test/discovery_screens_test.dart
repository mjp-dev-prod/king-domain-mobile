import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/core/formatting/currency.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/discovery.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/skill_submission.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/discovery_provider.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/skill_submissions_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/client/applicant_panel_card.dart';
import 'package:king_domain/presentation/widgets/kit/kd_button.dart';
import 'package:king_domain/presentation/screens/client/post_job_flow.dart';
import 'package:king_domain/presentation/screens/discovery/apply_screen.dart';
import 'package:king_domain/presentation/screens/discovery/browse_talents_screen.dart';
import 'package:king_domain/presentation/screens/discovery/invitations_screen.dart';
import 'package:king_domain/presentation/screens/discovery/saved_searches_screen.dart';
import 'package:king_domain/presentation/screens/discovery/shortlist_asks_screen.dart';
import 'package:king_domain/presentation/screens/discovery/talent_profile_screen.dart';
import 'package:king_domain/presentation/screens/jobs/job_feed_screen.dart';
import 'discovery_test_support.dart';

class _Auth extends AuthNotifier {
  final String role;
  _Auth(this.role);
  @override
  AuthState build() => AuthState(loading: false, user: AuthUser(id: 'u1', email: 'a@b.ng', role: role, fullName: 'Ada Obi', emailVerified: true));
}

class _EmptyJobs extends JobsNotifier {
  @override
  Future<List<Job>> build() async => const [];
}

/// Records what the screens ask the server to do.
class _Actions extends DiscoveryActions {
  _Actions(super.ref);
  static final calls = <String>[];
  static Map<String, dynamic>? lastPost;
  static ApiException? failNext;

  void _maybeFail() {
    final e = failNext;
    failNext = null;
    if (e != null) throw e;
  }

  @override
  Future<({Job job, bool held, String? reason})> postJob(Map<String, dynamic> body) async {
    _maybeFail();
    calls.add('post');
    lastPost = body;
    return (job: _job(), held: true, reason: 'first_post');
  }

  @override
  Future<void> apply(String jobId, {required int revision, required String answer, required List<Map<String, String>> pieces, required List<String> screeningAnswers}) async {
    _maybeFail();
    calls.add('apply $jobId pieces=${pieces.map((p) => '${p['type']}:${p['id']}').join(',')} answers=${screeningAnswers.join('|')}');
  }

  @override
  Future<void> saveSearch(String name, FeedFilters filters) async => calls.add('saveSearch $name ${filters.toSavedFilters()}');
  @override
  Future<void> setSearchAlerts(String id, bool on) async => calls.add('alerts $id $on');
  @override
  Future<void> deleteSearch(String id) async => calls.add('deleteSearch $id');
  @override
  Future<void> restoreSearch(SavedSearch s) async => calls.add('restoreSearch ${s.name}');
  @override
  Future<void> respondInvitation(String id, {required bool accept}) async => calls.add('respond $id $accept');
  @override
  Future<void> answerAsk(String itemId, {required bool available}) async => calls.add('ask $itemId $available');
  @override
  Future<void> invite(String jobId, String talentId, {String? message}) async => calls.add('invite $jobId $talentId ${message ?? ''}');
  @override
  Future<void> setSaved(String talentId, {required bool saved}) async => calls.add('saved $talentId $saved');
}

Job _job({String id = 'j1', String title = 'Reels for a salon', bool structured = true, bool paused = false, JobType type = JobType.oneDelivery, String currency = 'NGN', List<String> questions = const [], String? skill = 'short-form-video'}) => Job(
  id: id,
  title: title,
  category: 'Video & media',
  description: 'Edit three reels for a hair salon in Yaba.',
  budget: 25000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: DateTime.now().subtract(const Duration(hours: 2)),
  deliveryDays: 7,
  skillKey: structured ? skill : null,
  skillLabel: structured ? 'Short-form video editing' : null,
  jobType: type,
  currency: currency,
  paused: paused,
  pausedReason: paused ? 'days' : null,
  screeningQuestions: questions,
  brief: structured ? const {'deliverables': 'Three 30 second reels', 'quantity': 3, 'usageRights': 'organic'} : const {},
);

TalentCard _talent({String id = 't1', String name = 'Tobi Adeleke', bool isNew = false, bool saved = false, int done = 0}) => TalentCard(
  id: id,
  fullName: name,
  headline: 'Reels and shorts',
  verifiedSkills: [TalentSkill(skillKey: 'short-form-video', label: 'Short-form video editing', verifiedAt: DateTime.now().subtract(const Duration(days: 40)))],
  regionText: 'Yaba, Lagos, Nigeria',
  educationText: 'Student · UNILAG',
  completedJobs: done,
  newOnKingDomain: isNew,
  lastActive: 'today',
  identityVerified: true,
  saved: saved,
);

class _Talents extends TalentsNotifier {
  final List<TalentCard> list;
  _Talents(this.list);
  @override
  Future<TalentsState> build() async => TalentsState(talents: list, nextCursor: null);
}

SkillHub _hub({bool verified = true}) => SkillHub.fromJson({
  'uploadsAvailable': true,
  'skills': [
    {'skillKey': 'short-form-video', 'label': 'Short-form video editing', 'category': 'video', 'state': verified ? 'verified' : 'notStarted', 'currentSubmissionId': verified ? 's1' : null, 'attempts': 1, 'restriction': null, 'rubricDraft': true},
  ],
});

SubmissionDetail _submission() => SubmissionDetail.fromJson({
  'id': 's1', 'skillKey': 'short-form-video', 'skillLabel': 'Short-form video editing', 'status': 'verified',
  'declaredOwnWork': true, 'aiUsed': false, 'termsAccepted': false, 'termsNeeded': false, 'terms': [],
  'pieces': [
    {'id': 'p1', 'position': 1, 'title': 'Salon promo', 'brief': 'b', 'role': 'Editor', 'madeOn': 'March 2026', 'liveLink': '', 'files': []},
    {'id': 'p2', 'position': 2, 'title': 'Gym teaser', 'brief': 'b', 'role': 'Editor', 'madeOn': 'April 2026', 'liveLink': '', 'files': []},
    {'id': 'p3', 'position': 3, 'title': 'Cafe reel', 'brief': 'b', 'role': 'Editor', 'madeOn': 'May 2026', 'liveLink': '', 'files': []},
    {'id': 'p4', 'position': 4, 'title': 'Shop ad', 'brief': 'b', 'role': 'Editor', 'madeOn': 'June 2026', 'liveLink': '', 'files': []},
  ],
  'walkthrough': [],
  'readiness': {'items': [], 'ready': true},
  'limits': {'minPieces': 2, 'maxPieces': 3, 'files': {}},
  'rubric': {'draft': true, 'scale': [], 'lines': []},
  'result': {'outcome': 'verified'},
});

BriefSpec _spec() => BriefSpec.fromJson({
  'fields': [
    {'key': 'deliverables', 'label': 'What you want delivered', 'kind': 'text', 'required': true, 'max': 600},
    {'key': 'quantity', 'label': 'How many', 'kind': 'int', 'required': true, 'min': 1, 'max': 1000},
    {'key': 'usageRights', 'label': 'What the work may be used for', 'kind': 'choice', 'required': true, 'options': ['none', 'organic']},
  ],
});

Widget _app(Widget home, {String role = 'talent', List<Override> extra = const []}) => ProviderScope(
  key: UniqueKey(), // a second pump in one test must start from fresh providers, not keep the first overrides
  overrides: [
    authProvider.overrideWith(() => _Auth(role)),
    jobsProvider.overrideWith(_EmptyJobs.new),
    discoveryActionsProvider.overrideWith((ref) => _Actions(ref)),
    talentProfileProvider.overrideWith(() => _StaticProfile()),
    ...discoveryStubs(),
    ...extra,
  ],
  child: MaterialApp(theme: AppTheme.theme, home: home),
);

class _StaticProfile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async => const TalentProfile(headline: 'Editor', bio: 'b', skillCategories: ['Video & media'], payoutAccount: PayoutAccount(accountName: 'ADA OBI', accountNumberLast4: '6789'));
}

/// A widget test that lets a toast on screen finish, so one test's toast cannot leak into the next.
void dtest(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    t.view.physicalSize = const Size(1080, 2600);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    _Actions.calls.clear();
    _Actions.lastPost = null;
    _Actions.failNext = null;
    await body(t);
    await t.pump(const Duration(seconds: 5));
    await t.pump(const Duration(seconds: 1));
  });
}

extension on WidgetTester {
  Future<void> settle([int ms = 1100]) async {
    await pump();
    await pump(Duration(milliseconds: ms));
  }

  /// Presses a KdButton by calling what it would do, the way a tap would: a refusal (ShownError) is the button's own
  /// business. Used for buttons at the foot of a long form, where a tap can land on the edge of the screen.
  Future<void> pressButton(String label) async {
    final page = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
    await scrollUntilVisible(find.text(label), 300, scrollable: page);
    final button = widget<KdButton>(find.widgetWithText(KdButton, label, skipOffstage: false));
    try {
      await button.onPressed!();
    } on ShownError {
      // the screen already said why
    }
    await settle();
  }

  /// Scrolls the first scrollable until [text] is built and on screen, then taps it and waits for what follows.
  Future<void> tapText(String text, {bool waitAfter = true}) async {
    // The page's own list, not a text field's inner scrollable (which is first in the tree and cannot scroll the page).
    final page = find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
    await scrollUntilVisible(find.text(text), 200, scrollable: page);
    // Visible at the very edge is not tappable: move it well inside the screen.
    await drag(page, const Offset(0, -160));
    await pump();
    await tap(find.text(text));
    if (waitAfter) await settle();
  }
}

void main() {
  group('models', () {
    test('filters build the server query and the saved-search shape, and count what is active', () {
      final f = const FeedFilters().copyWith(skills: {'writing'}, types: {JobType.monthly}, market: 'international', budgetMin: 100, deliveryDaysMax: 7, verifiedClient: true, query: ' logo ');
      final q = f.toQuery(limit: 20);
      expect(q['skill'], 'writing');
      expect(q['type'], 'monthly');
      expect(q['market'], 'international');
      expect(q['budgetMin'], '100');
      expect(q['q'], 'logo');
      expect(q['forYou'], 'true');
      expect(f.toSavedFilters(), {'skillKeys': ['writing'], 'jobTypes': ['monthly'], 'currency': 'USD', 'budgetMin': 100, 'deliveryDaysMax': 7, 'query': 'logo'});
      expect(f.activeCount, 7);
      expect(const FeedFilters().isEmpty, isTrue, reason: 'for-you ordering is not a filter');
    });

    test('the filters in the sheet are worded for a person, and each knows how to come off', () {
      final f = const FeedFilters().copyWith(skills: {'writing'}, query: 'logo', types: {JobType.monthly, JobType.hourly}, market: 'international', budgetMin: 100, budgetMax: 500, deliveryDaysMax: 7, verifiedClient: true, fewApplicants: true);
      expect(f.active.map((a) => a.label), ['Monthly or Hourly', 'Paid in dollars', '${formatMoney(100, 'USD')} to ${formatMoney(500, 'USD')}', 'Within 7 days', 'Verified clients', 'Few applicants']);
      expect(f.active.length, 6, reason: 'search text and skill chips are on the screen already, so they are not listed');
      final without = f.active.firstWhere((a) => a.label.startsWith('Within')).without;
      expect(without.deliveryDaysMax, isNull);
      expect(without.market, 'international', reason: 'taking one off leaves the others on');
      expect(const FeedFilters(forYou: false).active, isEmpty);
      expect(const FeedFilters().copyWith(budgetMax: 5000).active.single.label, startsWith('Up to'));
    });

    test('a job carries its structured fields, and an old job still reads as one delivery in naira', () {
      final j = Job.fromJson({
        'id': 'a', 'title': 'T', 'category': 'Video & media', 'description': 'd', 'budget': '30000', 'createdAt': '2026-10-01T00:00:00Z',
        'skillKey': 'short-form-video', 'skillLabel': 'Short-form video editing', 'jobType': 'monthly', 'currency': 'USD', 'visibility': 'invite',
        'postStatus': 'rejected', 'rejection': {'reasonCode': 'vague', 'note': 'More detail'}, 'screeningQuestions': ['Q1?'], 'paused': true, 'pausedReason': 'days',
      });
      expect(j.jobType, JobType.monthly);
      expect(j.inviteOnly, isTrue);
      expect(j.needsChange, isTrue);
      expect(j.rejection!.note, 'More detail');
      expect(j.paused, isTrue);
      final old = Job.fromJson({'id': 'b', 'title': 'T', 'category': 'Design & creative', 'description': 'd', 'budget': '1000', 'createdAt': '2026-10-01T00:00:00Z'});
      expect(old.isStructured, isFalse);
      expect(old.jobType, JobType.oneDelivery);
      expect(old.currency, 'NGN');
      expect(old.skillOrCategory, 'Design & creative');
    });

    test('a shortlisted or declined application reads correctly to the talent', () {
      Job j(String s) => Job.fromJson({'id': 'a', 'title': 'T', 'category': 'c', 'description': 'd', 'budget': '1', 'createdAt': '2026-10-01T00:00:00Z', 'myApplicationStatus': s});
      expect(j('shortlisted').applicationStatus, JobApplicationStatus.pending, reason: 'a shortlist is the client\'s private list');
      expect(j('declined').applicationStatus, JobApplicationStatus.rejected);
    });
  });

  group('the job feed', () {
    dtest('shows each job with its type, price in its own currency, and how full it is', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: JobFeedScreen()), extra: discoveryStubs(feed: [_job(), _job(id: 'j2', title: 'Dollar shop site', type: JobType.hourly, currency: 'USD')])));
      await t.settle();
      expect(find.text('Reels for a salon'), findsOneWidget);
      expect(find.text('Monthly'), findsNothing);
      expect(find.text('One delivery'), findsOneWidget);
      expect(find.text('Hourly'), findsOneWidget);
      expect(find.text(r'$25,000 a week at most'), findsOneWidget);
      expect(find.text('0 of 50'), findsWidgets);
    });

    dtest('an unverified talent sees the gate on the card, a verified one sees "You qualify", a paused job says so', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: JobFeedScreen()), extra: [...discoveryStubs(feed: [_job(), _job(id: 'p', title: 'Paused job', paused: true)], hub: _hub())]));
      await t.settle();
      expect(find.text('You qualify'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      await t.pumpWidget(_app(const Scaffold(body: JobFeedScreen()), extra: [...discoveryStubs(feed: [_job()], hub: _hub(verified: false))]));
      await t.settle();
      expect(find.text('Needs verified proof'), findsOneWidget);
    });

    dtest('empty with no filters says why and points to Your skills; empty with filters says no match and offers Clear', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: JobFeedScreen())));
      await t.settle();
      expect(find.text('No open jobs right now'), findsOneWidget);
      expect(find.text('Your skills'), findsOneWidget);
      await t.tap(find.text('Graphic design'));
      await t.settle();
      expect(find.text('No jobs match'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    dtest('choosing a skill chip sets the filter, and the save-search button appears only then', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: JobFeedScreen())));
      await t.settle();
      expect(find.byTooltip('Save this search and get alerts'), findsNothing);
      await t.tap(find.text('Graphic design'));
      await t.settle();
      final container = ProviderScope.containerOf(t.element(find.byType(JobFeedScreen)));
      expect(container.read(feedFiltersProvider).skills, {'graphic-design'});
      expect(find.byTooltip('Save this search and get alerts'), findsOneWidget);
    });

    dtest('saving a search asks for a name, refuses an empty one, and sends the filters', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: JobFeedScreen())));
      await t.settle();
      await t.tap(find.text('Graphic design'));
      await t.settle();
      await t.tap(find.byTooltip('Save this search and get alerts'));
      await t.settle();
      await t.tap(find.text('Save and alert me'));
      await t.settle(1200);
      expect(_Actions.calls, isEmpty, reason: 'a name is required');
      await t.enterText(find.byType(TextField).last, 'Logos in naira');
      await t.tap(find.text('Save and alert me'));
      await t.settle(1200);
      expect(_Actions.calls.single, startsWith('saveSearch Logos in naira'));
      expect(_Actions.calls.single, contains('graphic-design'));
    });

    dtest('the filter sheet changes type and market, and Clear filters puts everything back', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: JobFeedScreen())));
      await t.settle();
      await t.tap(find.byTooltip('Filters'));
      await t.settle();
      await t.tap(find.text('Monthly'));
      await t.tap(find.text('Dollars'));
      await t.pump();
      await t.ensureVisible(find.text('Show jobs'));
      await t.tap(find.text('Show jobs'));
      await t.settle();
      final container = ProviderScope.containerOf(t.element(find.byType(JobFeedScreen)));
      expect(container.read(feedFiltersProvider).types, {JobType.monthly});
      expect(container.read(feedFiltersProvider).market, 'international');
      // What is on is said in words under the search, and a cross takes just that one off.
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Paid in dollars'), findsOneWidget);
      await t.tap(find.text('Paid in dollars'));
      await t.settle();
      expect(container.read(feedFiltersProvider).market, isNull);
      expect(container.read(feedFiltersProvider).types, {JobType.monthly});
      await t.tap(find.text('Monthly'));
      await t.settle();
      expect(find.text('Clear all'), findsNothing);
      expect(container.read(feedFiltersProvider).types, isEmpty);
    });
  });

  group('invitations, saved searches, asks', () {
    final now = DateTime.now();
    InvitationItem inv(String id, String status, Duration left) => InvitationItem(id: id, status: status, message: 'Your work fits.', expiresAt: now.add(left), from: 'Chinedu', job: _job());

    dtest('invitations: an open one shows its time left and can be declined; an expired one cannot', (t) async {
      await t.pumpWidget(_app(const InvitationsScreen(), extra: [invitationsProvider.overrideWith((ref) async => [inv('i1', 'pending', const Duration(hours: 30)), inv('i2', 'expired', const Duration(hours: -2))])]));
      await t.settle();
      expect(find.text('1 open'), findsOneWidget);
      expect(find.textContaining('left'), findsWidgets);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      await t.tap(find.text('Decline'));
      await t.settle();
      expect(_Actions.calls, ['respond i1 false']);
    });

    dtest('no invitations: says why and what to do', (t) async {
      await t.pumpWidget(_app(const InvitationsScreen()));
      await t.settle();
      expect(find.text('No invitations yet'), findsOneWidget);
      expect(find.text('Your skills'), findsOneWidget);
    });

    dtest('saved searches: an alert switch, and delete with Undo', (t) async {
      final s = SavedSearch(id: 's1', name: 'Reels in naira', filters: const {'skillKeys': ['short-form-video'], 'currency': 'NGN'}, alerts: true);
      await t.pumpWidget(_app(const SavedSearchesScreen(), extra: [savedSearchesProvider.overrideWith((ref) async => [s])]));
      await t.settle();
      expect(find.text('Reels in naira'), findsOneWidget);
      expect(find.text('1 skill · naira'), findsOneWidget);
      await t.tap(find.byType(Switch));
      await t.settle();
      expect(_Actions.calls, ['alerts s1 false']);
      await t.tap(find.byIcon(Icons.delete_outline_rounded));
      await t.settle();
      expect(_Actions.calls.last, 'deleteSearch s1');
      expect(find.text('Undo'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.settle();
      expect(_Actions.calls.last, 'restoreSearch Reels in naira');
    });

    dtest('saved searches: empty says how to make one', (t) async {
      await t.pumpWidget(_app(const SavedSearchesScreen()));
      await t.settle();
      expect(find.text('Nothing saved yet'), findsOneWidget);
    });

    dtest('are you free: a yes or a not now is sent, and an answered one just says what was said', (t) async {
      final asks = [
        ShortlistAsk(id: 'a1', askedAt: now.subtract(const Duration(minutes: 5)), available: null, skillLabel: 'Short-form video editing', budgetText: '₦30000'),
        ShortlistAsk(id: 'a2', askedAt: now.subtract(const Duration(days: 1)), available: true, skillLabel: 'Writing', budgetText: '₦10000'),
      ];
      await t.pumpWidget(_app(const ShortlistAsksScreen(), extra: [shortlistAsksProvider.overrideWith((ref) async => asks)]));
      await t.settle();
      expect(find.text('1 waiting'), findsOneWidget);
      expect(find.text('You said yes'), findsOneWidget);
      await t.tap(find.text("Yes, I'm free"));
      await t.settle();
      expect(_Actions.calls, ['ask a1 true']);
    });
  });

  group('applying', () {
    List<Override> over() => [skillHubProvider.overrideWith((ref) async => _hub()), submissionProvider('s1').overrideWith((ref) async => _submission())];

    dtest('shows the price rule, the verified pieces, and the client\'s questions', (t) async {
      await t.pumpWidget(_app(ApplyScreen(job: _job(questions: const ['Have you edited reels before?'])), extra: over()));
      await t.settle();
      expect(find.textContaining('nothing to bid'), findsOneWidget);
      expect(find.text('Salon promo', skipOffstage: false), findsOneWidget);
      expect(find.text('Have you edited reels before?', skipOffstage: false), findsOneWidget);
    });

    dtest('refuses an empty answer, no piece and a missing screening answer, each said inline', (t) async {
      await t.pumpWidget(_app(ApplyScreen(job: _job(questions: const ['Have you edited reels before?'])), extra: over()));
      await t.settle();
      await t.pressButton('Send application');
      expect(find.textContaining('at least 20 characters'), findsOneWidget);
      expect(find.text('Choose 1 to 3 pieces of your verified work to show.'), findsOneWidget);
      expect(find.text('Answer every question the client asked.'), findsOneWidget);
      expect(_Actions.calls, isEmpty);
    });

    dtest('up to three pieces; a fourth is refused with a reason; a good application is sent with exactly what was chosen', (t) async {
      await t.pumpWidget(_app(ApplyScreen(job: _job(questions: const ['Have you edited reels before?'])), extra: over()));
      await t.settle();
      await t.enterText(find.byType(TextFormField).at(0), 'I have edited reels for two salons and know this style well.');
      await t.ensureVisible(find.text('Salon promo'));
      for (final title in ['Salon promo', 'Gym teaser', 'Cafe reel']) {
        await t.ensureVisible(find.text(title));
        await t.tap(find.text(title));
        await t.pump();
      }
      await t.ensureVisible(find.text('Shop ad'));
      await t.tap(find.text('Shop ad'));
      await t.pump();
      expect(find.text('You can show up to 3 pieces.'), findsOneWidget);
      await t.enterText(find.byType(TextFormField).last, 'Yes, twenty of them.');
      await t.pressButton('Send application');
      expect(_Actions.calls.single, 'apply j1 pieces=piece:p1,piece:p2,piece:p3 answers=Yes, twenty of them.');
    });

    dtest('a cap or invitation refusal from the server is shown where the button is, and nothing is lost', (t) async {
      await t.pumpWidget(_app(ApplyScreen(job: _job()), extra: over()));
      await t.settle();
      await t.enterText(find.byType(TextFormField).at(0), 'I have edited reels for two salons and know this style well.');
      await t.ensureVisible(find.text('Salon promo'));
      await t.tap(find.text('Salon promo'));
      await t.pump();
      _Actions.failNext = ApiException('This job has been open for 5 days, so applications are paused.', 409, code: 'cap_paused');
      await t.pressButton('Send application');
      expect(find.textContaining('applications are paused'), findsOneWidget);
      expect(find.text('Send application'), findsOneWidget, reason: 'still on the form, to try again');
    });
  });

  group('the client side', () {
    dtest('browse talents: a card is facts, never a score, a newcomer is labelled, and Invite appears only for a job', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: BrowseTalentsScreen()), role: 'client', extra: [talentsProvider.overrideWith(() => _Talents([_talent(isNew: true), _talent(id: 't2', name: 'Ada Eze', done: 3)]))]));
      await t.settle();
      expect(find.text('Tobi Adeleke'), findsOneWidget);
      expect(find.text('New on King Domain'), findsOneWidget);
      expect(find.text('3 jobs done'), findsOneWidget);
      expect(find.text('Active today'), findsWidgets);
      expect(find.text('Invite to this job'), findsNothing);
      expect(find.textContaining('score'), findsNothing);
    });

    dtest('invited from a job: Invite opens a sheet with a note and sends it', (t) async {
      await t.pumpWidget(_app(BrowseTalentsScreen(forJob: _job()), role: 'client', extra: [talentsProvider.overrideWith(() => _Talents([_talent()]))]));
      await t.settle();
      await t.tap(find.text('Invite to this job'));
      await t.settle();
      expect(find.textContaining('72 hours'), findsWidgets);
      await t.enterText(find.byType(TextFormField).last, 'Your reels fit this.');
      await t.tap(find.text('Send invitation'));
      await t.settle(1200);
      expect(_Actions.calls.single, 'invite j1 t1 Your reels fit this.');
    });

    dtest('no talents: says why and offers find-someone', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: BrowseTalentsScreen()), role: 'client', extra: [talentsProvider.overrideWith(() => _Talents(const []))]));
      await t.settle();
      expect(find.text('No verified talents yet'), findsOneWidget);
      expect(find.text('Find someone for me'), findsWidgets);
    });

    dtest('a talent profile shows the verified work and saves or unsaves the talent', (t) async {
      final view = TalentProfileView(card: _talent(), bio: 'I edit short videos.', work: [
        VerifiedWork(skillKey: 'short-form-video', skillLabel: 'Short-form video editing', verifiedAt: DateTime.now().subtract(const Duration(days: 40)), pieces: const [
          WorkPiece(id: 'p1', title: 'Salon promo', brief: 'A 20 second promo', role: 'Editor', madeOn: 'March 2026', liveLink: null, files: [WorkFile(name: 'reel1.mp4', contentType: 'video/mp4', url: null)]),
        ]),
      ]);
      await t.pumpWidget(_app(const TalentProfileScreen(talentId: 't1'), role: 'client', extra: [talentProfileViewProvider('t1').overrideWith((ref) async => view)]));
      await t.settle();
      expect(find.text('I edit short videos.'), findsOneWidget);
      expect(find.text('Salon promo'), findsOneWidget);
      expect(find.textContaining('reel1.mp4'), findsOneWidget);
      await t.tap(find.text('Save this talent'));
      await t.settle();
      expect(_Actions.calls, ['saved t1 true']);
    });

    dtest('an applicant panel shows facts, the chosen work and answers, and Pick, Shortlist and Decline are there to use', (t) async {
      final app = JobApplication(
        id: 'a1', jobId: 'j1', talentId: 't1', talentName: 'Tobi Adeleke', status: 'pending', createdAt: DateTime.now(),
        panel: ApplicantPanel(
          talent: _talent(), answer: 'I know this style.', invited: true,
          screening: const [(question: 'Edited reels before?', answer: 'Yes, twenty.')],
          pieces: const [ApplicantPiece(title: 'Salon promo', brief: 'A promo', role: 'Editor', madeOn: 'March 2026', liveLink: null, files: [])],
        ),
      );
      final events = <String>[];
      await t.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: ApplicantPanelCard(app: app, awardedHere: false, canAct: true, onPick: () => events.add('pick'), onShortlist: () => events.add('shortlist'), onDecline: () => events.add('decline')))), role: 'client'));
      await t.settle();
      expect(find.text('Verified: Short-form video editing'), findsOneWidget);
      expect(find.text('You invited them'), findsOneWidget);
      expect(find.text('I know this style.'), findsOneWidget);
      expect(find.text('Salon promo'), findsOneWidget);
      expect(find.text('Yes, twenty.'), findsOneWidget);
      await t.tap(find.text('Shortlist'));
      await t.tap(find.text('Decline'));
      await t.tap(find.text('Pick Tobi'));
      expect(events, ['shortlist', 'decline', 'pick']);
    });

    dtest('a declined applicant is dimmed and offers no actions', (t) async {
      final app = JobApplication(id: 'a1', jobId: 'j1', talentId: 't1', talentName: 'Tobi Adeleke', status: 'declined', createdAt: DateTime.now(), panel: ApplicantPanel(talent: _talent(), answer: null, invited: false, screening: const [], pieces: const []));
      await t.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: ApplicantPanelCard(app: app, awardedHere: false, canAct: true, onPick: () {}, onShortlist: () {}, onDecline: () {}))), role: 'client'));
      await t.settle();
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Decline'), findsNothing);
    });
  });

  group('post a job', () {
    List<Override> specs() => [briefSpecProvider.overrideWith((ref, key) async => _spec())];

    Future<void> toBrief(WidgetTester t) async {
      await t.tap(find.text('One delivery'));
      await t.settle();
      await t.tap(find.text('Graphic design'));
      await t.settle();
    }

    dtest('walks type, skill, brief, price and questions to a review that states the money rules before posting', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: PostJobFlow()), role: 'client', extra: specs()));
      await t.settle();
      expect(find.text('What kind of job is it?'), findsOneWidget);
      expect(find.textContaining('no contests'), findsOneWidget);
      await toBrief(t);
      expect(find.text('Step 3 of 6'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Job title'), 'Logo for a bakery');
      await t.enterText(find.widgetWithText(TextFormField, 'What the job is, in your words'), 'A simple logo for a small bakery in Yaba, two colours.');
      await t.enterText(find.widgetWithText(TextFormField, 'What you want delivered'), 'One logo, three files');
      await t.enterText(find.widgetWithText(TextFormField, 'How many'), '1');
      await t.tapText('Posting on my own pages', waitAfter: false);
      await t.pressButton('Continue');
      expect(find.text('Price and delivery'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Price'), '25000');
      await t.pressButton('Continue');
      await t.pressButton('Continue');
      expect(find.text('Check it, then post'), findsOneWidget);
      expect(find.textContaining('You pay nothing now'), findsOneWidget);
      expect(find.textContaining('₦2,500'), findsOneWidget, reason: 'the 10% is shown before anything is paid');
      expect(find.textContaining('talent receives the full ₦25,000'), findsOneWidget);
      await t.pressButton('Post the job');
      expect(_Actions.calls, ['post']);
      expect(_Actions.lastPost!['skillKey'], 'graphic-design');
      expect(_Actions.lastPost!['jobType'], 'oneDelivery');
      expect(_Actions.lastPost!['price'], 25000.0);
      expect(_Actions.lastPost!['brief'], {'deliverables': 'One logo, three files', 'quantity': 1, 'usageRights': 'organic'});
      expect(find.text('A person is reading it first'), findsOneWidget, reason: 'a first post is held (D17), and the screen says so');
    });

    dtest('the brief step refuses a short title and a missing choice, in words, and keeps what was typed', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: PostJobFlow()), role: 'client', extra: specs()));
      await t.settle();
      await toBrief(t);
      await t.enterText(find.widgetWithText(TextFormField, 'Job title'), 'Hi');
      await t.pressButton('Continue');
      expect(find.text('Give the job a title of at least 5 characters.'), findsOneWidget);
      expect(find.text('Step 3 of 6'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Job title'), findsOneWidget);
    });

    dtest('the server naming a field takes the client back to the step that has it', (t) async {
      await t.pumpWidget(_app(const Scaffold(body: PostJobFlow()), role: 'client', extra: specs()));
      await t.settle();
      await toBrief(t);
      await t.enterText(find.widgetWithText(TextFormField, 'Job title'), 'Logo for a bakery');
      await t.enterText(find.widgetWithText(TextFormField, 'What the job is, in your words'), 'A simple logo for a small bakery in Yaba, two colours.');
      await t.enterText(find.widgetWithText(TextFormField, 'What you want delivered'), 'One logo');
      await t.enterText(find.widgetWithText(TextFormField, 'How many'), '1');
      await t.tapText('Posting on my own pages', waitAfter: false);
      await t.pressButton('Continue');
      await t.enterText(find.widgetWithText(TextFormField, 'Price'), '25000');
      await t.pressButton('Continue');
      await t.pressButton('Continue');
      _Actions.failNext = ApiException('How many: a whole number from 1 to 1000.', 400, data: {'field': 'quantity'});
      await t.pressButton('Post the job');
      expect(find.text('The brief'), findsOneWidget, reason: 'back on the step with the field');
      expect(find.text('How many: a whole number from 1 to 1000.'), findsOneWidget);
    });

    dtest('a post that was sent back shows why and what to do, and offers to send it again', (t) async {
      final held = Job(
        id: 'j9', title: 'Logo for a bakery', category: 'Design & creative', description: 'A simple logo for a small bakery in Yaba, two colours.', budget: 25000, clientId: 'c1', clientName: 'Me',
        postedAt: DateTime.now(), skillKey: 'graphic-design', skillLabel: 'Graphic design', postStatus: 'rejected', rejection: const PostRejection(reasonCode: 'vague', note: 'Say how many files.'),
        brief: const {'deliverables': 'One logo', 'quantity': 1, 'usageRights': 'organic'}, deliveryDays: 7,
      );
      await t.pumpWidget(_app(Scaffold(body: PostJobFlow(editing: held)), role: 'client', extra: specs()));
      await t.settle();
      expect(find.text('It needs a change before it goes live'), findsOneWidget);
      expect(find.textContaining('too vague'), findsOneWidget);
      expect(find.textContaining('Say how many files.'), findsOneWidget);
      expect(find.text('Change your job'), findsOneWidget);
    });
  });
}

