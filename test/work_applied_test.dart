import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/talent_profile.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/providers/talent_profile_provider.dart';
import 'package:king_domain/presentation/screens/jobs/job_detail_screen.dart';
import 'package:king_domain/presentation/screens/shell/applied_jobs.dart';
import 'package:king_domain/presentation/screens/shell/work_tab.dart';
import 'package:king_domain/presentation/widgets/kit/kd_card.dart';

final _now = DateTime.now();

Job _job(
  String id, {
  JobApplicationStatus app = JobApplicationStatus.notApplied,
  ContractStatus? contract,
  DateTime? closedAt,
  Duration age = const Duration(hours: 2),
}) => Job(
  id: id,
  title: 'Job $id',
  category: 'Design & creative',
  description: 'd',
  budget: 45000,
  clientId: 'c1',
  clientName: 'Chinedu',
  postedAt: _now.subtract(age),
  contractStatus: contract,
  applicationStatus: app,
  closedAt: closedAt,
  awardedApplicationId: contract != null ? 'a1' : null,
  deliveryDays: 5,
  deliverByAt: _now.add(const Duration(days: 3)),
);

class _Jobs extends JobsNotifier {
  _Jobs(this.jobs, {this.fail = false});
  final List<Job> jobs;
  final bool fail;
  @override
  Future<List<Job>> build() async {
    if (fail) throw Exception('offline');
    return jobs;
  }
}

class _Profile extends TalentProfileNotifier {
  @override
  Future<TalentProfile> build() async =>
      const TalentProfile(headline: 'h', bio: 'b', skillCategories: ['Design & creative'], proofItems: []);
}

Future<void> _show(WidgetTester tester, JobsNotifier jobs, {VoidCallback? onBrowse}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [jobsProvider.overrideWith(() => jobs), talentProfileProvider.overrideWith(_Profile.new)],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: Scaffold(body: WorkTab(onBrowseJobs: onBrowse ?? () {})),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('appliedJobs', () {
    test('keeps pending and not-picked applications only; selected ones are contracts, never-applied ones are not mine', () {
      final jobs = [
        _job('pending', app: JobApplicationStatus.pending),
        _job('lost', app: JobApplicationStatus.rejected),
        _job('won', app: JobApplicationStatus.accepted, contract: ContractStatus.funded),
        _job('none'),
      ];
      expect(appliedJobs(jobs).map((j) => j.id), ['pending', 'lost']);
    });

    test('waiting first, then newest first', () {
      final jobs = [
        _job('old-lost', app: JobApplicationStatus.rejected, age: const Duration(days: 9)),
        _job('new-lost', app: JobApplicationStatus.rejected, age: const Duration(days: 1)),
        _job('old-wait', app: JobApplicationStatus.pending, age: const Duration(days: 8)),
        _job('new-wait', app: JobApplicationStatus.pending, age: const Duration(days: 2)),
      ];
      expect(appliedJobs(jobs).map((j) => j.id), ['new-wait', 'old-wait', 'new-lost', 'old-lost']);
    });
  });

  group('appliedStatusLine', () {
    test('waiting is amber and names the client', () {
      final s = appliedStatusLine(_job('a', app: JobApplicationStatus.pending));
      expect(s.text, 'Waiting for Chinedu to pick');
      expect(s.tone, KdTone.warn);
    });

    test('not picked is neutral, closed by the client says so', () {
      final lost = appliedStatusLine(_job('a', app: JobApplicationStatus.rejected));
      expect(lost.text, 'Not picked');
      expect(lost.tone, KdTone.plain);
      final closed = appliedStatusLine(_job('b', app: JobApplicationStatus.rejected, closedAt: _now));
      expect(closed.text, 'Closed by the client');
      expect(closed.tone, KdTone.plain);
    });
  });

  group('Work tab segments', () {
    testWidgets('the Awarded segment is shown first, with counts on both labels', (tester) async {
      await _show(tester, _Jobs([
        _job('won', app: JobApplicationStatus.accepted, contract: ContractStatus.funded),
        _job('w1', app: JobApplicationStatus.pending),
        _job('w2', app: JobApplicationStatus.rejected),
      ]));
      expect(find.text('Awarded · 1'), findsOneWidget);
      expect(find.text('Applied · 2'), findsOneWidget);
      expect(find.text('Job won'), findsOneWidget);
      expect(find.text('Job w1'), findsNothing);
    });

    testWidgets('the Applied segment lists waiting first and shows each status line', (tester) async {
      await _show(tester, _Jobs([
        _job('lost', app: JobApplicationStatus.rejected, age: const Duration(days: 1)),
        _job('wait', app: JobApplicationStatus.pending),
        _job('closed', app: JobApplicationStatus.rejected, closedAt: _now, age: const Duration(days: 3)),
      ]));
      await tester.tap(find.text('Applied · 3'));
      await tester.pumpAndSettle();
      final order = ['Job wait', 'Job lost', 'Job closed'];
      final ys = order.map((t) => tester.getTopLeft(find.text(t)).dy).toList();
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Waiting for Chinedu to pick'), findsOneWidget);
      expect(find.text('Not picked'), findsOneWidget);
      expect(find.text('Closed by the client'), findsOneWidget);
    });

    testWidgets('empty Applied says why and Browse jobs works', (tester) async {
      var browsed = false;
      await _show(tester, _Jobs(const []), onBrowse: () => browsed = true);
      await tester.tap(find.text('Applied · 0'));
      await tester.pumpAndSettle();
      expect(find.text('No applications yet'), findsOneWidget);
      await tester.tap(find.text('Browse jobs'));
      expect(browsed, isTrue);
    });

    testWidgets('a load error shows Retry on the Applied segment too', (tester) async {
      await _show(tester, _Jobs(const [], fail: true));
      await tester.tap(find.text('Applied · 0'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Couldn\'t load'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('tapping an applied job opens it', (tester) async {
      await _show(tester, _Jobs([_job('wait', app: JobApplicationStatus.pending)]));
      await tester.tap(find.text('Applied · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Job wait'));
      await tester.pumpAndSettle();
      expect(find.byType(JobDetailScreen), findsOneWidget);
    });
  });
}
