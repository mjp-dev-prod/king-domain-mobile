import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/debug_log.dart';
import '../../data/api_client.dart';
import '../../data/models/messaging.dart';
import 'auth_provider.dart';
import 'skill_submissions_provider.dart' show PickedFile, blobUploaderProvider;

/// Conversations, newest first, with unread counts.
final conversationsProvider = FutureProvider<List<ConversationSummary>>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final data = await ApiClient.instance.get('/conversations') as Map<String, dynamic>;
  return [for (final c in data['conversations'] as List) ConversationSummary.fromJson(c as Map<String, dynamic>)];
});

/// How many messages are waiting, for the tab badge.
final unreadMessagesProvider = Provider<int>((ref) => ref.watch(conversationsProvider).valueOrNull?.fold<int>(0, (n, c) => n + c.unread) ?? 0);

/// Data saver (PRD §4.7): when on, nothing downloads by itself and sizes show first. A setting on this phone.
class DataSaverNotifier extends StateNotifier<bool> {
  DataSaverNotifier({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage(), super(false) {
    unawaited(_load());
  }
  final FlutterSecureStorage _storage;
  static const _key = 'kd_data_saver';

  Future<void> _load() async {
    try {
      state = (await _storage.read(key: _key)) == 'on';
    } catch (_) {
      // No stored value (or no storage in a test): stay off.
    }
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      await _storage.write(key: _key, value: on ? 'on' : 'off');
    } catch (_) {
      // The switch still works for this session if the phone can't save it.
    }
  }
}

final dataSaverProvider = StateNotifierProvider<DataSaverNotifier, bool>((ref) => DataSaverNotifier());

String newClientMsgId() {
  final r = Random.secure();
  return List.generate(20, (_) => r.nextInt(16).toRadixString(16)).join();
}

class ConversationState {
  final ConversationView view;
  /// Messages typed on this phone that the server has not confirmed: sending, or failed and waiting for Retry.
  final List<ChatMessage> pending;
  const ConversationState({required this.view, this.pending = const []});

  /// What the screen shows: the server's messages, then the ones still on their way, by time.
  List<ChatMessage> get all {
    final confirmed = {for (final m in view.messages) m.clientMsgId};
    final waiting = [for (final p in pending) if (!confirmed.contains(p.clientMsgId)) p];
    return [...view.messages, ...waiting]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
}

/// One open conversation: loads it, polls for new messages while the screen is open, and keeps what was typed
/// offline until it is sent (with the same id, so a retry never sends it twice).
class ConversationNotifier extends FamilyAsyncNotifier<ConversationState, String> {
  Timer? _timer;
  bool _polling = false;

  @override
  Future<ConversationState> build(String arg) async {
    ref.onDispose(() => _timer?.cancel());
    final data = await ApiClient.instance.get('/conversations/$arg') as Map<String, dynamic>;
    return ConversationState(view: ConversationView.fromJson(data));
  }

  /// Starts asking for new messages every few seconds (the screen calls this while it is on screen).
  void startPolling([Duration every = const Duration(seconds: 6)]) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => unawaited(poll()));
  }

  void stopPolling() => _timer?.cancel();

  Future<void> poll() async {
    final current = state.valueOrNull;
    if (current == null || _polling) return;
    _polling = true;
    try {
      final last = current.view.messages.where((m) => m.local == null).lastOrNull;
      final data = await ApiClient.instance.get('/conversations/$arg${last == null ? '' : '?after=${last.id}'}') as Map<String, dynamic>;
      final fresh = ConversationView.fromJson(data);
      // Held messages come back with every poll after their id: keep one copy of each.
      final seen = {for (final m in current.view.messages) m.id};
      final merged = [...current.view.messages, for (final m in fresh.messages) if (!seen.contains(m.id)) m];
      state = AsyncData(ConversationState(view: _with(fresh, merged), pending: current.pending));
      ref.invalidate(conversationsProvider);
    } on ApiException catch (e) {
      // A dropped connection while polling is not an error worth showing: the next poll tries again.
      kdLog('messages', 'poll failed: ${e.message}');
    } finally {
      _polling = false;
    }
  }

  ConversationView _with(ConversationView v, List<ChatMessage> messages) => ConversationView(
    id: v.id, otherId: v.otherId, otherName: v.otherName, otherPhotoUrl: v.otherPhotoUrl, iAmClient: v.iAmClient, awarded: v.awarded, canBlock: v.canBlock,
    blocked: v.blocked, uploadsAvailable: v.uploadsAvailable, messages: messages, events: v.events, reasons: v.reasons,
  );

  void _replacePending(String clientMsgId, ChatMessage? replacement, {ChatMessage? confirmed}) {
    final c = state.valueOrNull;
    if (c == null) return;
    final pending = [for (final p in c.pending) if (p.clientMsgId != clientMsgId) p, ?replacement];
    final messages = confirmed == null ? c.view.messages : [...c.view.messages.where((m) => m.id != confirmed.id), confirmed];
    state = AsyncData(ConversationState(view: _with(c.view, messages), pending: pending));
  }

  /// Sends a text. It shows at once as "sending"; if the connection fails it stays as "not sent" with Retry.
  /// A message held for breaking the rules comes back as held, with the reason, and the sender can change it.
  Future<void> send(String body, {String? clientMsgId}) async {
    final cid = clientMsgId ?? newClientMsgId();
    _replacePending(cid, ChatMessage.local(clientMsgId: cid, body: body, state: LocalState.sending));
    try {
      final data = await ApiClient.instance.post('/conversations/$arg/messages', body: {'clientMsgId': cid, 'body': body}) as Map<String, dynamic>;
      _replacePending(cid, null, confirmed: ChatMessage.fromJson(data['message'] as Map<String, dynamic>));
      ref.invalidate(conversationsProvider);
    } on ApiException catch (e) {
      kdLog('messages', 'send failed status=${e.status} code=${e.code} ${e.message}');
      // No connection (status 0): keep it to retry. A refusal from the server (blocked, invalid): drop it and say why.
      if (e.status == 0) {
        _replacePending(cid, ChatMessage.local(clientMsgId: cid, body: body, state: LocalState.failed));
      } else {
        _replacePending(cid, null);
      }
      rethrow;
    }
  }

  Future<void> retry(ChatMessage m) async {
    try {
      await send(m.body, clientMsgId: m.clientMsgId);
    } on ApiException {
      // send() has already put it back as "not sent".
    }
  }

  Future<void> edit(ChatMessage m, String body) async {
    final data = await ApiClient.instance.patch('/conversations/$arg/messages/${m.id}', body: {'body': body}) as Map<String, dynamic>;
    _replacePending('', null, confirmed: ChatMessage.fromJson(data['message'] as Map<String, dynamic>));
  }

  /// Sends a photo, a file or an audio file: ask for a link, upload straight to storage, then confirm.
  Future<void> sendAttachment({required String kind, required PickedFile file, int? durationSec, void Function(double)? onProgress}) async {
    final cid = newClientMsgId();
    final made = await ApiClient.instance.post('/conversations/$arg/attachments', body: {
      'clientMsgId': cid,
      'kind': kind,
      'name': file.name,
      'contentType': file.contentType,
      'sizeBytes': file.size,
      'durationSec': ?durationSec,
    }) as Map<String, dynamic>;
    final upload = made['upload'] as Map<String, dynamic>;
    final messageId = made['messageId'] as String;
    try {
      await ref.read(blobUploaderProvider).put(
        upload['url'] as String,
        {for (final e in (upload['headers'] as Map<String, dynamic>).entries) e.key: e.value as String},
        file.open(),
        file.size,
        onProgress: onProgress,
      );
      final done = await ApiClient.instance.post('/conversations/$arg/messages/$messageId/complete') as Map<String, dynamic>;
      _replacePending('', null, confirmed: ChatMessage.fromJson(done['message'] as Map<String, dynamic>));
      ref.invalidate(conversationsProvider);
    } catch (e) {
      kdLog('messages', 'attachment failed: $e');
      rethrow;
    }
  }

  Future<void> sendAgreement(String body) async {
    final data = await ApiClient.instance.post('/conversations/$arg/agreements', body: {'clientMsgId': newClientMsgId(), 'body': body}) as Map<String, dynamic>;
    _replacePending('', null, confirmed: ChatMessage.fromJson(data['message'] as Map<String, dynamic>));
  }

  Future<void> confirmAgreement(ChatMessage m) async {
    final data = await ApiClient.instance.post('/conversations/$arg/messages/${m.id}/confirm') as Map<String, dynamic>;
    _replacePending('', null, confirmed: ChatMessage.fromJson(data['message'] as Map<String, dynamic>));
  }

  Future<bool> report(ChatMessage m, {required String reasonCode, String? note}) async {
    final data = await ApiClient.instance.post('/conversations/$arg/messages/${m.id}/report', body: {'reasonCode': reasonCode, 'note': ?note}) as Map<String, dynamic>;
    return data['urgent'] as bool? ?? false;
  }

  Future<void> setBlocked(String otherId, {required bool blocked}) async {
    if (blocked) {
      await ApiClient.instance.post('/users/$otherId/block');
    } else {
      await ApiClient.instance.delete('/users/$otherId/block');
    }
    ref.invalidateSelf();
    ref.invalidate(conversationsProvider);
  }
}

final conversationProvider = AsyncNotifierProvider.family<ConversationNotifier, ConversationState, String>(ConversationNotifier.new);

/// Opens (or reopens) the conversation with a talent. Throws ApiException with code 'no_relationship' if the client
/// has no reason to write to them yet.
Future<String> startConversation(WidgetRef ref, String talentId) async {
  final data = await ApiClient.instance.post('/conversations', body: {'talentId': talentId}) as Map<String, dynamic>;
  ref.invalidate(conversationsProvider);
  return data['conversationId'] as String;
}
