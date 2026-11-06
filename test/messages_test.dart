import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/messaging.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/messaging_provider.dart';
import 'package:king_domain/presentation/screens/messages/messages_screen.dart';

class _Auth extends AuthNotifier {
  final String role;
  _Auth(this.role);
  @override
  AuthState build() => AuthState(loading: false, user: AuthUser(id: 'u1', email: 'a@b.ng', role: role, fullName: 'Ada Obi', emailVerified: true));
}

Future<void> _show(WidgetTester tester, {required String role, required Future<List<ConversationSummary>> Function() list}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _Auth(role)),
      conversationsProvider.overrideWith((ref) => list()),
    ],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const Scaffold(body: MessagesScreen()),
    ),
  ));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _msg(String id, {bool mine = true, String state = 'sent', String? heldWhy, String body = 'hello', DateTime? at, String? clientMsgId}) => {
  'id': id,
  'clientMsgId': clientMsgId ?? id,
  'kind': 'text',
  'mine': mine,
  'state': state,
  'body': body,
  'heldWhy': heldWhy,
  'createdAt': (at ?? DateTime(2026, 10, 30, 12)).toIso8601String(),
};

void main() {
  group('the messages tab', () {
    testWidgets('a client with nothing yet is told who they can write to', (tester) async {
      await _show(tester, role: 'client', list: () async => const []);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.textContaining('someone who applied to your job'), findsOneWidget);
    });

    testWidgets('a talent with nothing yet is told clients write first', (tester) async {
      await _show(tester, role: 'talent', list: () async => const []);
      expect(find.textContaining('Clients message you once you have applied'), findsOneWidget);
    });

    testWidgets('conversations show the other person, a preview, and how many are waiting', (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await _show(tester, role: 'client', list: () async => [
        const ConversationSummary(id: 'c1', otherId: 't1', otherName: 'Ada Obi', preview: 'Can you start Monday?', lastMine: true, unread: 0),
        const ConversationSummary(id: 'c2', otherId: 't2', otherName: 'Tunde Bello', preview: 'Sent the draft', unread: 3),
        const ConversationSummary(id: 'c3', otherId: 't3', otherName: 'Zainab Musa', preview: 'x', blocked: true),
      ]);
      expect(find.text('Ada Obi'), findsOneWidget);
      expect(find.text('You: Can you start Monday?'), findsOneWidget);
      expect(find.text('Tunde Bello'), findsOneWidget);
      expect(find.bySemanticsLabel('3 unread'), findsOneWidget);
      expect(find.text('Blocked'), findsOneWidget, reason: 'a blocked conversation hides its preview');
    });

    testWidgets('a held last message is marked as not sent', (tester) async {
      await _show(tester, role: 'talent', list: () async => [
        const ConversationSummary(id: 'c1', otherId: 'k1', otherName: 'Chinedu', preview: 'Pay me on whatsapp', lastMine: true, lastHeld: true),
      ]);
      expect(find.text('You: Not sent. Pay me on whatsapp'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry, not a blank page', (tester) async {
      await _show(tester, role: 'client', list: () async => throw ApiException('down', 500));
      expect(find.textContaining('Couldn\'t load your messages'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('the data saver switch lives in Settings, so the tab is just the conversations', (tester) async {
      await _show(tester, role: 'client', list: () async => const []);
      expect(find.textContaining('Data saver'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('messages', () {
    test('a held message knows it was held and cannot be edited', () {
      final m = ChatMessage.fromJson(_msg('m1', state: 'held', heldWhy: 'phone_number'));
      expect(m.held, isTrue);
      expect(m.heldWhy, 'phone_number');
      expect(m.canEditNow(), isFalse);
    });

    test('an edit window that is open allows an edit, and a closed one does not', () {
      final open = ChatMessage.fromJson({..._msg('m1'), 'editableUntil': DateTime.now().add(const Duration(minutes: 5)).toIso8601String()});
      final closed = ChatMessage.fromJson({..._msg('m2'), 'editableUntil': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String()});
      final theirs = ChatMessage.fromJson({..._msg('m3', mine: false), 'editableUntil': DateTime.now().add(const Duration(minutes: 5)).toIso8601String()});
      expect(open.canEditNow(), isTrue);
      expect(closed.canEditNow(), isFalse);
      expect(theirs.canEditNow(), isFalse, reason: 'only the sender edits');
    });

    test('a message typed offline is shown once, in order, and never twice when the server confirms it', () {
      final view = ConversationView.fromJson({
        'conversation': {
          'id': 'c1',
          'other': {'id': 't1', 'fullName': 'Ada Obi'},
          'iAmClient': true,
          'awarded': false,
          'canBlock': true,
          'blocked': false,
          'uploadsAvailable': true,
        },
        'messages': [_msg('m1', at: DateTime(2026, 10, 30, 10)), _msg('m2', clientMsgId: 'cm2', at: DateTime(2026, 10, 30, 11))],
        'events': const [],
        'reasons': const [],
      });
      final waiting = ChatMessage.local(clientMsgId: 'cm2', body: 'hello', state: LocalState.sending);
      final failed = ChatMessage.local(clientMsgId: 'cm3', body: 'later', state: LocalState.failed);
      final state = ConversationState(view: view, pending: [waiting, failed]);
      final ids = state.all.map((m) => m.clientMsgId).toList();
      expect(ids.where((i) => i == 'cm2').length, 1, reason: 'the confirmed copy replaces the pending one');
      expect(ids.last, 'cm3', reason: 'what is still on its way comes last');
    });
  });
}
