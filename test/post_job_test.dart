import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/providers/jobs_provider.dart';
import 'package:king_domain/presentation/screens/client/post_job_screen.dart';

class _Jobs extends JobsNotifier {
  final posted = <String>[];

  @override
  Future<List<Job>> build() async => const [];

  @override
  Future<Job> postJob({required String title, required String category, required String description, required double budget, required int deliveryDays}) async {
    posted.add('$title|$category|$budget|$deliveryDays');
    return Job(id: 'new', title: title, category: category, description: description, budget: budget, clientId: 'c1', clientName: 'C', postedAt: DateTime.now());
  }
}

Future<(_Jobs, List<String>)> _show(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final jobs = _Jobs();
  final events = <String>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [jobsProvider.overrideWith(() => jobs)],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      // Hosted like the shell hosts it: a tab, not a pushed route.
      home: Scaffold(body: PostJobScreen(onPosted: () => events.add('posted'))),
    ),
  ));
  await tester.pumpAndSettle();
  return (jobs, events);
}

Future<void> _tapPost(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Post job'), 300, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('Post job'));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an incomplete form marks what is missing and sends nothing', (tester) async {
    final (jobs, events) = await _show(tester);
    await _tapPost(tester);
    expect(jobs.posted, isEmpty);
    expect(events, isEmpty);
    expect(find.text('Pick one'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('posts with the chosen category and delivery time, then hands back to the shell', (tester) async {
    final (jobs, events) = await _show(tester);

    await tester.tap(find.text('Design & creative'));
    await tester.enterText(find.byType(TextField).at(0), 'Logo for a campus cafe');
    await tester.enterText(find.byType(TextField).at(1), 'A simple logo and two colour variants for signage.');
    await tester.enterText(find.byType(TextField).at(2), '45000');
    await tester.scrollUntilVisible(find.text('14 days'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('14 days'));
    await tester.pump();

    await _tapPost(tester);
    expect(jobs.posted, ['Logo for a campus cafe|Design & creative|45000.0|14']);
    expect(events, ['posted'], reason: 'the shell switches tabs; the screen must not pop the root route');
    expect(find.text('Logo for a campus cafe'), findsNothing, reason: 'the form resets for the next job');

    await tester.pump(const Duration(seconds: 6)); // let the toast time out
    await tester.pumpAndSettle();
  });
}
