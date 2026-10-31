// Conversations as the server describes them (backend src/conversations.js; PRD §4.7, decisions D18, D27).

DateTime _date(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dateOrNull(Object? v) => v == null ? null : DateTime.tryParse(v as String)?.toLocal();

class ConversationSummary {
  final String id;
  final String otherId;
  final String otherName;
  final String? otherPhotoUrl;
  final String? preview;
  final bool lastMine;
  final bool lastHeld;
  final DateTime? lastAt;
  final int unread;
  final bool blocked;

  const ConversationSummary({required this.id, required this.otherId, required this.otherName, this.otherPhotoUrl, this.preview, this.lastMine = false, this.lastHeld = false, this.lastAt, this.unread = 0, this.blocked = false});

  factory ConversationSummary.fromJson(Map<String, dynamic> j) {
    final other = j['other'] as Map<String, dynamic>;
    final last = j['last'] as Map<String, dynamic>?;
    return ConversationSummary(
      id: j['id'] as String,
      otherId: other['id'] as String,
      otherName: other['fullName'] as String,
      otherPhotoUrl: other['photoUrl'] as String?,
      preview: last?['preview'] as String?,
      lastMine: last?['mine'] as bool? ?? false,
      lastHeld: last?['held'] as bool? ?? false,
      lastAt: _dateOrNull(last?['at']),
      unread: (j['unread'] as num?)?.toInt() ?? 0,
      blocked: j['blocked'] as bool? ?? false,
    );
  }
}

enum MessageKind { text, voice, image, file, agreement }

class MessageAttachment {
  final String name;
  final String contentType;
  final int sizeBytes;
  final int? durationSec;
  final String? url;
  const MessageAttachment({required this.name, required this.contentType, required this.sizeBytes, this.durationSec, this.url});

  factory MessageAttachment.fromJson(Map<String, dynamic> j) => MessageAttachment(
    name: j['name'] as String,
    contentType: j['contentType'] as String,
    sizeBytes: (j['sizeBytes'] as num).toInt(),
    durationSec: (j['durationSec'] as num?)?.toInt(),
    url: j['url'] as String?,
  );
}

class AgreementState {
  final bool confirmedByMe;
  final bool confirmedByOther;
  final bool agreed;
  const AgreementState({required this.confirmedByMe, required this.confirmedByOther, required this.agreed});

  factory AgreementState.fromJson(Map<String, dynamic> j) => AgreementState(confirmedByMe: j['confirmedByMe'] as bool, confirmedByOther: j['confirmedByOther'] as bool, agreed: j['status'] == 'agreed');
}

/// The sending state of a message the phone made itself: on its way, delivered, or failed and waiting for Retry.
enum LocalState { sending, failed }

class ChatMessage {
  final String id;
  final String clientMsgId;
  final MessageKind kind;
  final bool mine;
  /// sent, or held (not delivered: it broke the rules for before an award).
  final String state;
  final String body;
  final String? heldWhy;
  final bool edited;
  final DateTime? editableUntil;
  final DateTime createdAt;
  final MessageAttachment? attachment;
  final AgreementState? agreement;
  final LocalState? local;

  const ChatMessage({
    required this.id,
    required this.clientMsgId,
    required this.kind,
    required this.mine,
    required this.state,
    required this.body,
    this.heldWhy,
    this.edited = false,
    this.editableUntil,
    required this.createdAt,
    this.attachment,
    this.agreement,
    this.local,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    clientMsgId: (j['clientMsgId'] as String?) ?? j['id'] as String,
    kind: MessageKind.values.where((k) => k.name == j['kind']).firstOrNull ?? MessageKind.text,
    mine: j['mine'] as bool,
    state: j['state'] as String? ?? 'sent',
    body: (j['body'] as String?) ?? '',
    heldWhy: j['heldWhy'] as String?,
    edited: j['edited'] as bool? ?? false,
    editableUntil: _dateOrNull(j['editableUntil']),
    createdAt: _date(j['createdAt']),
    attachment: j['attachment'] == null ? null : MessageAttachment.fromJson(j['attachment'] as Map<String, dynamic>),
    agreement: j['agreement'] == null ? null : AgreementState.fromJson(j['agreement'] as Map<String, dynamic>),
  );

  /// A message typed on this phone, not yet confirmed by the server.
  factory ChatMessage.local({required String clientMsgId, required String body, required LocalState state, MessageKind kind = MessageKind.text}) =>
      ChatMessage(id: 'local-$clientMsgId', clientMsgId: clientMsgId, kind: kind, mine: true, state: 'sent', body: body, createdAt: DateTime.now(), local: state);

  bool get held => state == 'held';
  bool canEditNow([DateTime? now]) => kind == MessageKind.text && !held && local == null && mine && editableUntil != null && (now ?? DateTime.now()).isBefore(editableUntil!);

  ChatMessage withLocal(LocalState s) => ChatMessage(id: id, clientMsgId: clientMsgId, kind: kind, mine: mine, state: state, body: body, createdAt: createdAt, local: s);
}

class ChatEvent {
  final String id;
  final String jobId;
  final String jobTitle;
  final String type;
  final DateTime at;
  const ChatEvent({required this.id, required this.jobId, required this.jobTitle, required this.type, required this.at});

  factory ChatEvent.fromJson(Map<String, dynamic> j) => ChatEvent(id: j['id'] as String, jobId: j['jobId'] as String, jobTitle: (j['jobTitle'] as String?) ?? 'the job', type: j['type'] as String, at: _date(j['at']));

  /// What happened, in words a person reads in a timeline.
  String get text => switch (type) {
    'awarded' => 'Awarded: waiting for payment',
    'funded' => 'Paid and held by King Domain',
    'started' => 'Work started',
    'submitted' => 'Delivered for review',
    'approved' => 'Approved. Payment released',
    'changesRequested' => 'Changes requested',
    'extensionRequested' => 'More time requested',
    'extensionGranted' => 'More time granted',
    'extensionDeclined' => 'More time declined',
    _ => type,
  };
}

class ReportReason {
  final String code;
  final String label;
  const ReportReason(this.code, this.label);
}

class ConversationView {
  final String id;
  final String otherId;
  final String otherName;
  final String? otherPhotoUrl;
  final bool iAmClient;
  final bool awarded;
  final bool canBlock;
  final bool blocked;
  final bool uploadsAvailable;
  final List<ChatMessage> messages;
  final List<ChatEvent> events;
  final List<ReportReason> reasons;

  const ConversationView({
    required this.id,
    required this.otherId,
    required this.otherName,
    this.otherPhotoUrl,
    required this.iAmClient,
    required this.awarded,
    required this.canBlock,
    required this.blocked,
    required this.uploadsAvailable,
    required this.messages,
    required this.events,
    required this.reasons,
  });

  factory ConversationView.fromJson(Map<String, dynamic> j) {
    final c = j['conversation'] as Map<String, dynamic>;
    final other = c['other'] as Map<String, dynamic>;
    return ConversationView(
      id: c['id'] as String,
      otherId: other['id'] as String,
      otherName: other['fullName'] as String,
      otherPhotoUrl: other['photoUrl'] as String?,
      iAmClient: c['iAmClient'] as bool,
      awarded: c['awarded'] as bool? ?? false,
      canBlock: c['canBlock'] as bool? ?? true,
      blocked: c['blocked'] as bool? ?? false,
      uploadsAvailable: c['uploadsAvailable'] as bool? ?? false,
      messages: [for (final m in j['messages'] as List) ChatMessage.fromJson(m as Map<String, dynamic>)],
      events: [for (final e in (j['events'] as List? ?? const [])) ChatEvent.fromJson(e as Map<String, dynamic>)],
      reasons: [for (final r in (j['reasons'] as List? ?? const [])) ReportReason((r as Map)['code'] as String, r['label'] as String)],
    );
  }
}
