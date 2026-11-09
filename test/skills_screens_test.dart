import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/skill_submission.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/skill_submissions_provider.dart';
import 'package:king_domain/presentation/screens/skills/skills_hub_screen.dart';
import 'package:king_domain/presentation/screens/skills/skills_row.dart';
import 'package:king_domain/presentation/screens/skills/submission_screen.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(loading: false, user: AuthUser(id: 'u1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true));
}

/// Records what the screens ask the server to do, and answers like the server would.
class _Actions extends SubmissionActions {
  _Actions(super.ref);
  final calls = <String>[];
  ApiException? failSubmit;

  @override
  Future<void> submit(String id) async {
    calls.add('submit $id');
    if (failSubmit != null) throw failSubmit!;
  }

  @override
  Future<void> updateDeclaration(String id, {bool? ownWork, bool? aiUsed, String? aiNote, bool? acceptTerms}) async {
    calls.add('declare own=$ownWork ai=$aiUsed terms=$acceptTerms');
  }

  @override
  Future<SubmissionDetail> startOrContinue(String skillKey) async {
    calls.add('start $skillKey');
    return SubmissionDetail.fromJson(_detail(status: 'draft', id: 'new1'));
  }

  @override
  Future<void> addFile(String id, {required FileRole role, String? pieceId, required PickedFile file, void Function(double fraction)? onProgress}) async {
    calls.add('addFile ${role.name} ${file.name}');
    onProgress?.call(.5);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> deleteFile(String id, String fileId) async => calls.add('deleteFile $fileId');
}

class _Gateway implements FileGateway {
  List<PickedFile> media = const [];
  PickedFile? video;
  @override
  Future<List<PickedFile>> pickMedia() async => media;
  @override
  Future<List<PickedFile>> pickDocuments() async => media;
  @override
  Future<PickedFile?> recordVideo() async => video;
  @override
  Future<PickedFile?> pickVideo() async => video;
}

PickedFile _file(String name, {int size = 1000, String? type}) => PickedFile(name: name, size: size, contentType: type ?? contentTypeFor(name), open: () => const Stream.empty());

const _limits = {
  'output': {'maxBytes': 500 * 1024 * 1024, 'types': ['image/png', 'image/jpeg', 'video/mp4', 'application/pdf']},
  'working': {'maxBytes': 500 * 1024 * 1024, 'types': ['image/png', 'video/mp4', 'application/octet-stream']},
  'draft': {'maxBytes': 200 * 1024 * 1024, 'types': ['image/png', 'video/mp4']},
  'walkthrough': {'maxBytes': 300 * 1024 * 1024, 'types': ['video/mp4']},
};

Map<String, dynamic> _fileJson(String id, String role, {String? pieceId, String name = 'clip.mp4', String type = 'video/mp4'}) =>
    {'id': id, 'role': role, 'pieceId': pieceId, 'name': name, 'contentType': type, 'sizeBytes': 2048, 'status': 'ready'};

Map<String, dynamic> _detail({
  String id = 's1',
  String status = 'draft',
  bool ready = false,
  List<Map<String, dynamic>>? pieces,
  List<Map<String, dynamic>> walkthrough = const [],
  Map<String, dynamic>? result,
  bool termsNeeded = false,
  bool aiUsed = false,
  String? submittedAt,
  String? decidedAt,
}) => {
  'id': id,
  'skillKey': 'short-form-video',
  'skillLabel': 'Short-form video editing',
  'status': status,
  'declaredOwnWork': ready,
  'aiUsed': aiUsed,
  'aiNote': null,
  'termsAccepted': false,
  'termsNeeded': termsNeeded,
  'terms': ['Send only your own work.', 'Do not resend rejected work unchanged.'],
  'submittedAt': submittedAt,
  'decidedAt': decidedAt,
  'pieces': pieces ?? const [],
  'walkthrough': walkthrough,
  'readiness': {
    'items': [
      {'key': 'pieces', 'label': '2 or 3 pieces of real work', 'done': ready},
      {'key': 'walkthrough', 'label': 'A 2 to 3 minute walkthrough video', 'done': ready},
      {'key': 'declaration', 'label': 'Your declaration that the work is yours', 'done': ready},
    ],
    'ready': ready,
  },
  'limits': {'minPieces': 2, 'maxPieces': 3, 'files': _limits},
  'rubric': {
    'draft': true,
    'scale': [],
    'lines': [
      {'key': 'sound', 'label': 'Sound', 'looksLike': 'Dialogue is clear.'},
      {'key': 'text', 'label': 'Captions and titles', 'looksLike': 'Readable and well timed.'},
    ],
  },
  'result': result,
};

Map<String, dynamic> _hubEntry(String key, String label, String state, {String? id, Map<String, dynamic>? restriction}) => {
  'skillKey': key, 'label': label, 'category': 'video', 'state': state, 'currentSubmissionId': id, 'attempts': 0, 'restriction': restriction, 'rubricDraft': true,
};

SkillHub _hub(List<Map<String, dynamic>> entries, {bool uploads = true}) => SkillHub.fromJson({'skills': entries, 'uploadsAvailable': uploads});

late _Gateway _gateway;

/// The fake the screens are talking to (built the first time something reads it, so read it through the tree).
_Actions _acts(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(MaterialApp))).read(submissionActionsProvider) as _Actions;

Widget _app(Widget home, {SkillHub? hub, Map<String, SubmissionDetail>? submissions, Map<String, List<HistoryEntry>>? history}) => ProviderScope(
  overrides: [
    authProvider.overrideWith(() => _Auth()),
    skillHubProvider.overrideWith((ref) async => hub ?? _hub([])),
    for (final e in (submissions ?? {}).entries) submissionProvider(e.key).overrideWith((ref) async => e.value),
    skillHistoryProvider.overrideWith((ref, key) async => history?[key] ?? const []),
    submissionActionsProvider.overrideWith((ref) => _Actions(ref)),
    fileGatewayProvider.overrideWithValue(_gateway = _Gateway()),
  ],
  child: MaterialApp(theme: AppTheme.theme, home: home),
);

SubmissionDetail _d(Map<String, dynamic> json) => SubmissionDetail.fromJson(json);

/// A widget test that lets any toast on screen finish its timer, so one test's toast can't leak into the next.
void skillTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  });
}

extension on WidgetTester {
  Future<void> settle([int ms = 700]) async {
    await pump();
    await pump(Duration(milliseconds: ms));
  }
}

void main() {
  group('models', () {
    test('a detail parses with its pieces, files, limits and readiness', () {
      final d = _d(_detail(pieces: [
        {'id': 'p1', 'position': 1, 'title': 'Reel', 'brief': 'b', 'role': 'Editor', 'madeOn': 'March', 'liveLink': '', 'files': [_fileJson('f1', 'output', pieceId: 'p1'), _fileJson('f2', 'working', pieceId: 'p1')]},
      ], walkthrough: [_fileJson('w1', 'walkthrough')]));
      expect(d.pieces.single.detailsDone, isTrue);
      expect(d.pieces.single.filesOf(FileRole.output), hasLength(1));
      expect(d.hasWalkthrough, isTrue);
      expect(d.limits[FileRole.walkthrough]!.types, ['video/mp4']);
      expect(d.ready, isFalse);
      expect(d.maxPieces, 3);
    });

    test('a not-yet result keeps the lines and the reviewers\' words, and history merges the status into the result', () {
      final h = HistoryEntry.fromJson({
        'id': 'h1', 'status': 'notYet', 'submittedAt': '2026-10-01T10:00:00Z', 'decidedAt': null,
        'result': {'kind': 'review', 'lines': [{'key': 'sound', 'label': 'Sound', 'looksLike': 'x', 'score': 1}], 'comments': ['Too loud']},
      });
      expect(h.result!.outcome, SubmissionStatus.notYet);
      expect(h.result!.lines.single.score, 1);
      expect(h.result!.comments, ['Too loud']);
    });

    test('content types come from the extension, and unknown files are plain binary', () {
      expect(contentTypeFor('Reel.MP4'), 'video/mp4');
      expect(contentTypeFor('final.pdf'), 'application/pdf');
      expect(contentTypeFor('project.prproj'), 'application/octet-stream');
      expect(contentTypeFor('noextension'), 'application/octet-stream');
    });
  });

  group('SkillsHubScreen', () {
    skillTest('lists each skill with where it stands, and a restricted one says when it ends', (tester) async {
      await tester.pumpWidget(_app(const SkillsHubScreen(), hub: _hub([
        _hubEntry('short-form-video', 'Short-form video editing', 'verified', id: 's1'),
        _hubEntry('writing', 'Writing', 'notStarted'),
        _hubEntry('graphic-design', 'Graphic design', 'restricted', restriction: {'kind': 'repeat', 'until': '2027-01-15T00:00:00Z', 'reason': 'Sent rejected work again'}),
      ])));
      await tester.settle();
      expect(find.text('Your skills'), findsOneWidget);
      expect(find.text('1 verified'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('To do'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.textContaining('You can submit again after'), findsOneWidget);
    });

    skillTest('paused uploads are said plainly at the top', (tester) async {
      await tester.pumpWidget(_app(const SkillsHubScreen(), hub: _hub([_hubEntry('writing', 'Writing', 'notStarted')], uploads: false)));
      await tester.settle();
      expect(find.text('Uploads are paused'), findsOneWidget);
    });

    skillTest('a skill not started opens the intro: how it works, how long, the rules, and Start begins a draft', (tester) async {
      await tester.pumpWidget(_app(const SkillsHubScreen(), hub: _hub([_hubEntry('short-form-video', 'Short-form video editing', 'notStarted')])));
      await tester.settle();
      await tester.tap(find.text('Short-form video editing'));
      await tester.settle();
      expect(find.text('How it works'), findsOneWidget);
      expect(find.textContaining('within $replyDays days'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Start'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Only send work you made'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.settle();
      expect(_acts(tester).calls, ['start short-form-video']);
    });

    skillTest('a paused skill has no Start, only the reason and when it ends', (tester) async {
      final entry = SkillHubEntry.fromJson(_hubEntry('writing', 'Writing', 'restricted', restriction: {'kind': 'ban', 'until': null, 'reason': 'Work was not yours'}));
      await tester.pumpWidget(_app(SkillIntroScreen(entry: entry)));
      await tester.settle();
      expect(find.text("You can't submit in Writing"), findsOneWidget);
      expect(find.textContaining('Work was not yours'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    skillTest('a loading failure has a retry, not a blank', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(() => _Auth()), skillHubProvider.overrideWith((ref) async => throw ApiException('x', 500))],
        child: MaterialApp(theme: AppTheme.theme, home: const SkillsHubScreen()),
      ));
      await tester.settle();
      expect(find.textContaining("Couldn't load your skills"), findsOneWidget);
    });
  });

  group('SkillsRow', () {
    skillTest('says nothing is verified yet and where to start', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: SkillsRow()), hub: _hub([_hubEntry('writing', 'Writing', 'notStarted')])));
      await tester.settle();
      expect(find.text('Your skills'), findsOneWidget);
      expect(find.text('None verified yet · tap to start'), findsOneWidget);
    });
  });

  group('draft', () {
    skillTest('shows what is still missing, and Send explains the first thing to do instead of failing silently', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': _d(_detail())}));
      await tester.settle();
      expect(find.text('Before you can send'), findsOneWidget);
      expect(find.text('2 or 3 pieces of real work'), findsOneWidget);
      expect(find.text('0 of 3 ready'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Send for checking'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Send for checking'));
      await tester.settle(1200);
      expect(find.textContaining('Still to do: 2 or 3 pieces of real work'), findsOneWidget);
      expect(_acts(tester).calls.where((c) => c.startsWith('submit')), isEmpty);
    });

    skillTest('the standard is visible before sending, and flagged as a draft', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': _d(_detail())}));
      await tester.settle();
      await tester.tap(find.text('What the reviewers look for'));
      await tester.settle();
      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Dialogue is clear.'), findsOneWidget);
      expect(find.textContaining('first draft'), findsOneWidget);
    });

    skillTest('ready: says so, asks to confirm because it can not be changed after, then sends', (tester) async {
      final ready = _d(_detail(ready: true, pieces: [
        {'id': 'p1', 'position': 1, 'title': 'Reel', 'brief': 'b', 'role': 'Editor', 'madeOn': 'March', 'liveLink': '', 'files': [_fileJson('f1', 'output', pieceId: 'p1')]},
      ], walkthrough: [_fileJson('w1', 'walkthrough')]));
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': ready}));
      await tester.settle();
      expect(find.text('Ready to send'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Send for checking'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Send for checking'));
      await tester.settle();
      expect(find.text('Send it for checking?'), findsOneWidget);
      expect(find.textContaining("can't change it"), findsOneWidget);
      await tester.tap(find.text('Send it'));
      await tester.settle(1200);
      expect(_acts(tester).calls, contains('submit s1'));
    });

    skillTest('"Not yet" in the confirmation sends nothing', (tester) async {
      final ready = _d(_detail(ready: true, pieces: [
        {'id': 'p1', 'position': 1, 'title': 'Reel', 'brief': 'b', 'role': 'Editor', 'madeOn': 'March', 'liveLink': '', 'files': [_fileJson('f1', 'output', pieceId: 'p1')]},
      ], walkthrough: [_fileJson('w1', 'walkthrough')]));
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': ready}));
      await tester.settle();
      await tester.scrollUntilVisible(find.text('Send for checking'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Send for checking'));
      await tester.settle();
      await tester.tap(find.text('Not yet'));
      await tester.settle(1200);
      expect(_acts(tester).calls.where((c) => c.startsWith('submit')), isEmpty);
    });

    skillTest('after a not-yet, the terms must be accepted, and the switch records it', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': _d(_detail(termsNeeded: true))}));
      await tester.settle();
      await tester.scrollUntilVisible(find.text('Before you send again'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Do not resend rejected work unchanged.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('I have read and accept these terms'), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byType(Switch).last);
      await tester.settle();
      await tester.tap(find.byType(Switch).last);
      await tester.settle();
      expect(_acts(tester).calls, contains('declare own=null ai=null terms=true'));
    });
  });

  group('files', () {
    SubmissionDetail withPiece() => _d(_detail(pieces: [
      {'id': 'p1', 'position': 1, 'title': 'Reel', 'brief': 'b', 'role': 'Editor', 'madeOn': 'March', 'liveLink': '', 'files': const []},
    ]));

    skillTest('the walkthrough: record, upload, and the file arrives through the actions', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': withPiece()}));
      await tester.settle();
      await tester.scrollUntilVisible(find.text('Add the walkthrough'), 300, scrollable: find.byType(Scrollable).first);
      _gateway.video = _file('walk.mp4');
      await tester.tap(find.text('Add the walkthrough'));
      await tester.settle();
      await tester.tap(find.text('Record now'));
      await tester.settle(300);
      expect(_acts(tester).calls, ['addFile walkthrough walk.mp4']);
    });

    skillTest('a kind of file that is not accepted is refused with the file name, before anything is sent', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': withPiece()}));
      await tester.settle();
      await tester.scrollUntilVisible(find.text('Add the walkthrough'), 300, scrollable: find.byType(Scrollable).first);
      _gateway.video = _file('walk.pdf');
      await tester.tap(find.text('Add the walkthrough'));
      await tester.settle();
      await tester.tap(find.text('Choose a video from your phone'));
      await tester.settle(300);
      expect(find.textContaining("walk.pdf: that kind of file can't be added as walkthrough"), findsOneWidget);
      expect(_acts(tester).calls, isEmpty);
    });

    skillTest('a file over the limit says how big it is and what the limit is', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': withPiece()}));
      await tester.settle();
      await tester.scrollUntilVisible(find.text('Add the walkthrough'), 300, scrollable: find.byType(Scrollable).first);
      _gateway.video = _file('walk.mp4', size: 400 * 1024 * 1024);
      await tester.tap(find.text('Add the walkthrough'));
      await tester.settle();
      await tester.tap(find.text('Record now'));
      await tester.settle(300);
      expect(find.textContaining('The limit here is'), findsOneWidget);
      expect(_acts(tester).calls, isEmpty);
    });

    skillTest('a file already added can be removed', (tester) async {
      final d = _d(_detail(walkthrough: [_fileJson('w1', 'walkthrough', name: 'walk.mp4')], pieces: [
        {'id': 'p1', 'position': 1, 'title': 'Reel', 'brief': 'b', 'role': 'Editor', 'madeOn': 'March', 'liveLink': '', 'files': const []},
      ]));
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': d}));
      await tester.settle();
      await tester.scrollUntilVisible(find.text('walk.mp4'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.settle();
      expect(_acts(tester).calls, ['deleteFile w1']);
      expect(find.text('Add the walkthrough'), findsNothing, reason: 'one walkthrough only, so the add button is hidden while one is there');
    });
  });

  group('waiting', () {
    skillTest('at the authenticity check: says a person is checking it is theirs, when to expect a reply, and that nothing is needed', (tester) async {
      await tester.pumpWidget(_app(
        const SubmissionScreen(submissionId: 's1'),
        submissions: {'s1': _d(_detail(status: 'authenticity', submittedAt: DateTime.now().subtract(const Duration(hours: 5)).toUtc().toIso8601String(), pieces: [
          {'id': 'p1', 'position': 1, 'title': 'Reel', 'brief': 'b', 'role': 'Editor', 'madeOn': 'March', 'liveLink': '', 'files': const []},
        ]))},
      ));
      await tester.settle();
      expect(find.text('A person is checking it is yours'), findsOneWidget);
      expect(find.textContaining('within $replyDays days'), findsOneWidget);
      expect(find.textContaining('nothing you need to do'), findsOneWidget);
      expect(find.text('Scored by two reviewers'), findsOneWidget);
      expect(find.text('Reel'), findsOneWidget);
    });

    skillTest('at review: says two reviewers are judging, blind, with a third if they differ', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': _d(_detail(status: 'review'))}));
      await tester.settle();
      expect(find.text('Two reviewers are judging it'), findsOneWidget);
      expect(find.textContaining('a third reviewer decides'), findsOneWidget);
    });
  });

  group('results', () {
    skillTest('verified: confirms it, what it unlocks, and closes', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {'s1': _d(_detail(status: 'verified', result: {'outcome': 'verified'}))}));
      await tester.settle();
      expect(find.text('You are verified in Short-form video editing'), findsOneWidget);
      expect(find.textContaining('apply to Short-form video editing jobs'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    skillTest('not yet: lists the lines that fell short with what good looks like, the reviewers\' words, and how to go again', (tester) async {
      await tester.pumpWidget(_app(
        const SubmissionScreen(submissionId: 's1'),
        submissions: {
          's1': _d(_detail(status: 'notYet', result: {
            'outcome': 'notYet', 'kind': 'review',
            'lines': [{'key': 'sound', 'label': 'Sound', 'looksLike': 'Dialogue is clear.', 'score': 1}, {'key': 'text', 'label': 'Captions and titles', 'looksLike': 'Readable.', 'score': 2}],
            'comments': ['The dialogue is buried under the music.'],
          })),
        },
      ));
      await tester.settle();
      expect(find.text('Not yet'), findsWidgets);
      expect(find.text('What fell short'), findsOneWidget);
      expect(find.text('Below the standard'), findsOneWidget);
      expect(find.text('Nearly there'), findsOneWidget);
      expect(find.textContaining('What good looks like: Dialogue is clear.'), findsOneWidget);
      expect(find.text('Fix it and send again'), findsOneWidget);
      expect(find.textContaining('2 months, then 3'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('never see who the reviewers were'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('buried under the music'), findsOneWidget);
    });

    skillTest('Fix it and send again starts a new draft and opens it', (tester) async {
      await tester.pumpWidget(_app(
        const SubmissionScreen(submissionId: 's1'),
        submissions: {'s1': _d(_detail(status: 'notYet', result: {'outcome': 'notYet', 'kind': 'review', 'lines': [], 'comments': []})), 'new1': _d(_detail(id: 'new1'))},
      ));
      await tester.settle();
      await tester.tap(find.text('Fix it and send again'));
      await tester.settle(1000);
      expect(_acts(tester).calls, ['start short-form-video']);
      expect(find.text('Before you can send'), findsOneWidget);
    });

    skillTest('stopped at the authenticity check without a penalty: says why and offers to go again', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {
        's1': _d(_detail(status: 'notYet', result: {'outcome': 'notYet', 'kind': 'authenticity', 'note': 'The walkthrough does not show you explaining the work.'})),
      }));
      await tester.settle();
      expect(find.text('We could not tell yet that this is your work'), findsOneWidget);
      expect(find.textContaining('does not show you explaining the work'), findsOneWidget);
      expect(find.text('Fix it and send again'), findsOneWidget);
    });

    skillTest('a time-out for resending rejected work says until when, and offers no way around it', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {
        's1': _d(_detail(status: 'notYet', result: {'outcome': 'notYet', 'kind': 'authenticity', 'note': 'Same files as before.', 'restrictedUntil': '2027-03-01T00:00:00Z'})),
      }));
      await tester.settle();
      expect(find.textContaining("You can't submit until"), findsOneWidget);
      expect(find.text('Fix it and send again'), findsNothing);
    });

    skillTest('a ban says what it is and how to contest it', (tester) async {
      await tester.pumpWidget(_app(const SubmissionScreen(submissionId: 's1'), submissions: {
        's1': _d(_detail(status: 'removed', result: {'outcome': 'removed', 'kind': 'removed', 'note': 'This reel is on another channel.'})),
      }));
      await tester.settle();
      expect(find.text("You can't submit in Short-form video editing"), findsOneWidget);
      expect(find.textContaining('This reel is on another channel.'), findsOneWidget);
      expect(find.textContaining('contact support'), findsOneWidget);
    });

    skillTest('earlier attempts are listed with their outcome', (tester) async {
      await tester.pumpWidget(_app(
        const SubmissionScreen(submissionId: 's2'),
        submissions: {'s2': _d(_detail(id: 's2', status: 'verified', result: {'outcome': 'verified'}))},
        history: {
          'short-form-video': [
            HistoryEntry.fromJson({'id': 's1', 'status': 'notYet', 'submittedAt': '2026-10-01T10:00:00Z', 'decidedAt': '2026-10-03T10:00:00Z', 'result': {'kind': 'review', 'lines': [], 'comments': []}}),
            HistoryEntry.fromJson({'id': 's2', 'status': 'verified', 'submittedAt': '2026-10-10T10:00:00Z', 'decidedAt': null, 'result': {'outcome': 'verified'}}),
          ],
        },
      ));
      await tester.settle();
      await tester.scrollUntilVisible(find.text('Earlier attempts'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Not yet'), findsOneWidget, reason: 'only the earlier attempt is listed, not the one on screen');
    });
  });

  skillTest('a draft that fails to load has a retry', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(() => _Auth()), submissionProvider('s1').overrideWith((ref) async => throw ApiException('x', 500))],
      child: MaterialApp(theme: AppTheme.theme, home: const SubmissionScreen(submissionId: 's1')),
    ));
    await tester.settle();
    expect(find.textContaining("Couldn't load this"), findsOneWidget);
  });
}
