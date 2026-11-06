import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/reputation.dart';
import 'package:king_domain/presentation/providers/reputation_provider.dart';
import 'package:king_domain/presentation/screens/contracts/review_screen.dart';
import 'package:king_domain/presentation/widgets/kit/reputation_widgets.dart';

final _now = DateTime.now();

const _clientQuestions = [
  ReviewQuestion(key: 'followedBrief', label: 'Did they follow the brief?', kind: 'triple'),
  ReviewQuestion(key: 'recommend', label: 'Would you recommend them?', kind: 'bool'),
];

ReviewState _state({String state = 'can_review', ReviewBody? mine, ReviewBody? theirs, bool theirsExists = false, bool canEdit = false, bool canReply = false}) => ReviewState(
  role: 'client',
  direction: 'client_to_talent',
  questions: _clientQuestions,
  privateQuestion: 'Would you work with this person again? Only King Domain sees this answer.',
  facts: const JobFacts(startProofHours: 5, deliveredOnTime: true, changeRounds: 1),
  otherName: 'Ada Obi',
  state: state,
  message: state == 'not_yet' ? 'You can review once the job has been paid out.' : null,
  windowEndsAt: _now.add(const Duration(days: 9)),
  daysLeft: 9,
  mine: mine,
  theirs: theirs,
  theirsExists: theirsExists,
  canEdit: canEdit,
  canReply: canReply,
);

class _Actions extends ReviewActions {
  _Actions(super.ref);
  static final calls = <String>[];
  static ApiException? failNext;

  @override
  Future<void> submit(String jobId, {required Map<String, dynamic> answers, required String comment, required bool privateAgain}) async {
    final e = failNext;
    failNext = null;
    if (e != null) throw e;
    calls.add('submit:${answers.entries.map((x) => '${x.key}=${x.value}').join(',')}|$comment|$privateAgain');
  }

  @override
  Future<void> reply(String jobId, String text) async => calls.add('reply:$text');
}

Future<void> _show(WidgetTester tester, ReviewState state) async {
  tester.view.physicalSize = const Size(1080, 2800);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  _Actions.calls.clear();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      reviewProvider('j1').overrideWith((ref) async => state),
      reviewActionsProvider.overrideWith((ref) => _Actions(ref)),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const ReviewScreen(jobId: 'j1', jobTitle: 'Logo and brand kit'),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// The form is taller than the phone. A tap that lands off-screen does nothing, so a test could "prove" a button is
/// disabled by simply missing it. Scroll to the target first.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

void main() {
  group('writing a review', () {
    testWidgets('shows what the system recorded, specific questions and a private one, with no stars', (tester) async {
      await _show(tester, _state());
      expect(find.text('What we recorded'), findsOneWidget);
      expect(find.textContaining('Delivered on time'), findsOneWidget);
      expect(find.text('Did they follow the brief?'), findsOneWidget);
      expect(find.text('Partly'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.textContaining('Only King Domain sees this answer'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_border), findsNothing);
    });

    testWidgets('cannot be sent until every question, including the private one, is answered', (tester) async {
      await _show(tester, _state());
      await _tap(tester, find.text('Send my review'));
      await tester.pumpAndSettle();
      expect(_Actions.calls, isEmpty);
      expect(find.text('Answer every question to send it.'), findsOneWidget);

      await _tap(tester, find.text('Yes').first);
      await _tap(tester, find.text('Yes').at(1));
      await _tap(tester, find.text('Yes').last);
      await tester.enterText(find.byType(TextField), 'Sent drafts early.');
      await _tap(tester, find.text('Send my review'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls.single, contains('followedBrief=yes'));
      expect(_Actions.calls.single, contains('recommend=true'));
      expect(_Actions.calls.single, endsWith('|Sent drafts early.|true'));
      await _drain(tester);
    });

    testWidgets('says when the other side has already written theirs, without showing it', (tester) async {
      await _show(tester, _state(theirsExists: true));
      expect(find.textContaining('already written theirs'), findsOneWidget);
    });

    testWidgets('a refused send shows the reason and keeps what was typed', (tester) async {
      await _show(tester, _state());
      await _tap(tester, find.text('Yes').first);
      await _tap(tester, find.text('Yes').at(1));
      await _tap(tester, find.text('No').last);
      _Actions.failNext = ApiException('The 14 days to review this job have passed.', 409);
      await _tap(tester, find.text('Send my review'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('The 14 days to review this job have passed.'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('waiting and revealed', () {
    const mine = ReviewBody(id: 'r1', answers: {'followedBrief': 'yes', 'recommend': true}, comment: 'Great.', privateAgain: true);

    testWidgets('after sending, theirs stays hidden and says why, and mine can still be changed', (tester) async {
      await _show(tester, _state(state: 'waiting', mine: mine, canEdit: true));
      expect(find.text('Your review'), findsOneWidget);
      expect(find.text('Theirs is hidden for now'), findsOneWidget);
      expect(find.text('Change my review'), findsOneWidget);
      expect(find.textContaining('What Ada Obi wrote'), findsNothing);
    });

    testWidgets('once both are in, both are shown, theirs can be replied to, and it is locked', (tester) async {
      const theirs = ReviewBody(id: 'r2', answers: {'briefClear': 'yes', 'recommend': true}, comment: 'Clear brief, paid fast.');
      await _show(tester, _state(state: 'revealed', mine: mine, theirs: theirs, canReply: true));
      expect(find.text('What Ada Obi wrote'), findsOneWidget);
      expect(find.text('"Clear brief, paid fast."'), findsOneWidget);
      expect(find.text('Change my review'), findsNothing);
      await tester.tap(find.text('Reply to what Ada Obi wrote'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Thank you, a pleasure.');
      await tester.pump();
      await tester.tap(find.text('Post reply'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_Actions.calls, ['reply:Thank you, a pleasure.']);
      await _drain(tester);
    });

    testWidgets('after 14 days without a review, says so instead of offering a form', (tester) async {
      await _show(tester, _state(state: 'window_closed'));
      expect(find.text('The 14 days passed'), findsOneWidget);
      expect(find.text('Send my review'), findsNothing);
    });

    testWidgets('before the job is paid, says when it will open', (tester) async {
      await _show(tester, _state(state: 'not_yet'));
      expect(find.text('Not yet'), findsWidgets);
      expect(find.text('Send my review'), findsNothing);
    });
  });

  group('what profiles show', () {
    Widget host(Widget child) => ProviderScope(child: MaterialApp(theme: AppTheme.theme, home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child))));

    testWidgets('counts per skill, Proven, and reviews recent first, with no average anywhere', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final rep = TalentReputation(
        completedJobs: 6,
        skills: const [SkillTally(skillKey: 'short-form-video', skillLabel: 'Short-form video editing', jobs: 6, onTime: 6, reviewed: 6, recommend: 5)],
        proven: const [ProvenInfo(skillKey: 'short-form-video', skillLabel: 'Short-form video editing', proven: true, completed: 6, needed: 3, recommended: 6, unmet: [])],
        reviewCount: 2,
        reviews: [
          PublicReview(id: 'a', direction: 'client_to_talent', jobTitle: 'Reel', skillLabel: 'Short-form video editing', at: _now, answers: const {'followedBrief': 'yes', 'recommend': true}, comment: 'Fast and clean.', reply: 'Thanks!', facts: const JobFacts(deliveredOnTime: true, changeRounds: 0), older: false),
          PublicReview(id: 'b', direction: 'client_to_talent', jobTitle: 'Old reel', skillLabel: 'Short-form video editing', at: _now.subtract(const Duration(days: 500)), answers: const {'recommend': true}, comment: 'Good.', reply: null, facts: null, older: true),
        ],
      );
      await tester.pumpWidget(host(TalentReputationSection(reputation: rep)));
      await tester.pumpAndSettle();
      expect(find.text('6 jobs in Short-form video editing · 6 on time · 5 of 6 clients would recommend'), findsOneWidget);
      expect(find.text('Proven: Short-form video editing'), findsOneWidget);
      expect(find.text('"Fast and clean."'), findsOneWidget);
      expect(find.textContaining('Their reply: Thanks!'), findsOneWidget);
      expect(find.text('"Good."'), findsNothing, reason: 'older than 12 months waits behind a tap');
      await tester.tap(find.text('Show older reviews (1)'));
      await tester.pumpAndSettle();
      expect(find.text('"Good."'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.textContaining('average'), findsNothing);
    });

    testWidgets('a talent with no finished jobs gets an honest empty state', (tester) async {
      await tester.pumpWidget(host(const TalentReputationSection(reputation: TalentReputation())));
      await tester.pumpAndSettle();
      expect(find.textContaining('No finished jobs on King Domain yet'), findsOneWidget);
    });

    testWidgets('a client\'s record shows counts and habits, and nothing before there is something to count', (tester) async {
      await tester.pumpWidget(host(const ClientReputationBlock(reputation: ClientReputation())));
      await tester.pumpAndSettle();
      expect(find.textContaining('No finished jobs yet'), findsOneWidget);

      await tester.pumpWidget(host(const ClientReputationBlock(
        reputation: ClientReputation(tally: ClientTally(reviewed: 5, briefClear: 4, feedbackClear: 3, paidFairly: 5, recommend: 4), reviewHoursMedian: 20, changeRoundsPerJob: 0.6, jobsDone: 5, disputesLost: 0),
      )));
      await tester.pumpAndSettle();
      expect(find.text('4 of 5 talents said the brief was clear'), findsOneWidget);
      expect(find.text('Reviews delivered work in about 20 h'), findsOneWidget);
      expect(find.text('0 disputes lost'), findsOneWidget);
    });
  });
}
