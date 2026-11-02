import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/models/sent_work.dart';
import 'package:king_domain/presentation/providers/sent_work_provider.dart';
import 'package:king_domain/presentation/screens/skills/sent_work_screen.dart';

class _Probe implements MediaProbe {
  final Duration? length;
  const _Probe(this.length);
  @override
  Future<Duration?> videoLength(String url) async => length;
}

SentFile _file(String id, String name, SentKind kind, {String role = 'finished', String? url}) => SentFile(id: id, role: role, name: name, contentType: 'x/x', sizeBytes: 2048, kind: kind, url: url);

const _liveUrl = 'https://example.com/brand-kit';
const _processUrl = 'https://www.figma.com/file/abc';

SentWork _work({String verdict = 'complete_with_advice', List<SentFile>? walkthrough, bool aiUsed = true}) => SentWork(
  id: 's1',
  skillKey: 'graphic_design',
  skillLabel: 'Graphic design',
  status: 'submitted',
  submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
  verdict: verdict,
  headline: 'Everything asked for is there',
  detail: 'Two things are worth a look before a reviewer opens it.',
  howMadePrompt: 'Show how you made it',
  howMadeOptions: const ['A screen recording of the file open', 'Your Figma link'],
  requirements: const [
    SentRequirement(key: 'pieces', label: '3 pieces of work', done: true, why: 'Reviewers judge a pattern, not a single lucky piece.'),
    SentRequirement(key: 'walkthrough', label: 'A walkthrough video', done: true, why: 'You explaining the work is the strongest proof it is yours.'),
  ],
  pieces: [
    SentPiece(
      id: 'p1',
      position: 1,
      title: 'Brand kit for a bakery',
      brief: 'A full identity for a small bakery in Yaba: logo, colours, type and a one page guide.',
      role: 'Designer',
      madeOn: 'Figma',
      liveLink: _liveUrl,
      processLink: _processUrl,
      finished: [_file('f1', 'kit.pdf', SentKind.pdf)],
      howMade: [_file('h1', 'process.mp4', SentKind.video, role: 'working')],
      checks: const [
        SentCheck(key: 'details', state: 'ok', label: 'Details filled in', detail: 'Role and tool are given.'),
        SentCheck(key: 'brief', state: 'advice', label: 'Brief is short', detail: 'A longer brief helps a reviewer judge it.'),
      ],
    ),
  ],
  walkthrough: walkthrough ?? [_file('w1', 'walk.mp4', SentKind.video, role: 'walkthrough', url: 'https://files.example/walk.mp4')],
  ownWork: true,
  aiUsed: aiUsed,
  aiNote: 'Used it to name colours.',
);

LinkPreview _preview(String url, {bool ok = true}) => ok
    ? LinkPreview(ok: true, url: url, host: Uri.parse(url).host, title: 'Bakery brand kit', description: 'The full identity.', siteName: 'Example')
    : LinkPreview(ok: false, url: url, host: Uri.parse(url).host, reason: 'The page wasn\'t found (404). Check the link.');

Future<void> _show(WidgetTester tester, {SentWork? work, Duration? length = const Duration(minutes: 2, seconds: 30), bool processOk = true, bool fail = false}) async {
  tester.view.physicalSize = const Size(1080, 18000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sentWorkProvider('s1').overrideWith((ref) async {
        if (fail) throw Exception('offline');
        return work ?? _work();
      }),
      linkPreviewProvider(_liveUrl).overrideWith((ref) async => _preview(_liveUrl)),
      linkPreviewProvider(_processUrl).overrideWith((ref) async => _preview(_processUrl, ok: processOk)),
      mediaProbeProvider.overrideWithValue(_Probe(length)),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const SentWorkScreen(submissionId: 's1'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says what was asked and why, and whether each part is there', (tester) async {
    await _show(tester);
    expect(find.text('What you sent'), findsOneWidget);
    expect(find.text('Everything asked for is there'), findsOneWidget);
    expect(find.text('3 pieces of work'), findsOneWidget);
    expect(find.text('Reviewers judge a pattern, not a single lucky piece.'), findsOneWidget);
    expect(find.text('A walkthrough video'), findsOneWidget);
  });

  testWidgets('lays out each piece with its brief, files, previewed links and checks', (tester) async {
    await _show(tester);
    expect(find.text('Brand kit for a bakery'), findsOneWidget);
    expect(find.textContaining('a small bakery in Yaba'), findsOneWidget);
    expect(find.text('kit.pdf'), findsOneWidget);
    expect(find.text('process.mp4'), findsOneWidget);
    // Both links unfurl into a card with the page's own title.
    expect(find.text('Bakery brand kit'), findsNWidgets(2));
    expect(find.text('Details filled in'), findsOneWidget);
    expect(find.text('Brief is short'), findsOneWidget);
    expect(find.text('A longer brief helps a reviewer judge it.'), findsOneWidget);
  });

  testWidgets('a link that can\'t be read says why and how to get past it', (tester) async {
    await _show(tester, processOk: false);
    expect(find.text('The link that shows how it was made couldn\'t be previewed'), findsOneWidget);
    expect(find.textContaining('The page wasn\'t found (404)'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Open it myself'), findsOneWidget);
  });

  testWidgets('reads the walkthrough\'s real length against the 2 to 3 minutes asked', (tester) async {
    await _show(tester);
    expect(find.textContaining('Within the 2 to 3 minutes asked for'), findsOneWidget);
  });

  testWidgets('a walkthrough that is too short is advice, not a block', (tester) async {
    await _show(tester, length: const Duration(seconds: 40));
    expect(find.textContaining('Shorter than the 2 to 3 minutes'), findsOneWidget);
  });

  testWidgets('a length that can\'t be read tells the person to play it and check', (tester) async {
    await _show(tester, length: null);
    expect(find.textContaining('Couldn\'t read its length'), findsOneWidget);
  });

  testWidgets('shows the declaration, including what AI was used for', (tester) async {
    await _show(tester);
    expect(find.text('Your declaration'), findsOneWidget);
    expect(find.text('"Used it to name colours."'), findsOneWidget);
  });

  testWidgets('a missing walkthrough is said plainly', (tester) async {
    await _show(tester, work: _work(verdict: 'gaps', walkthrough: const []));
    expect(find.text('No walkthrough was sent.'), findsOneWidget);
    expect(find.text('Gaps'), findsOneWidget);
  });

  testWidgets('when it can\'t load there is a way to retry', (tester) async {
    await _show(tester, fail: true);
    expect(find.textContaining('Couldn\'t load what you sent'), findsOneWidget);
  });
}
