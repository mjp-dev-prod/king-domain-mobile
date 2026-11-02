// Mirrors king-domain-backend's GET /users/me/submissions/:id/work and /users/link-preview: everything a person sent for a
// skill, laid out to be looked at. Read-only; a sent submission can't be changed.

DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
List<Map<String, dynamic>> _maps(Object? v) => [for (final e in (v as List? ?? const [])) e as Map<String, dynamic>];

enum SentKind { image, video, audio, pdf, other }

SentKind _kind(String? v) => SentKind.values.where((k) => k.name == v).firstOrNull ?? SentKind.other;

/// One file the person sent, with a private link that expires (about an hour), or null if storage isn't available.
class SentFile {
  final String id;
  final String role;
  final String name;
  final String contentType;
  final int sizeBytes;
  final SentKind kind;
  final String? url;
  const SentFile({required this.id, required this.role, required this.name, required this.contentType, required this.sizeBytes, required this.kind, required this.url});

  factory SentFile.fromJson(Map<String, dynamic> j) => SentFile(
    id: j['id'] as String,
    role: j['role'] as String? ?? '',
    name: j['name'] as String? ?? 'File',
    contentType: j['contentType'] as String? ?? '',
    sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
    kind: _kind(j['kind'] as String?),
    url: j['url'] as String?,
  );
}

/// Plain advice on one piece. [state] is ok, advice (worth knowing, never blocking) or missing.
class SentCheck {
  final String key;
  final String state;
  final String label;
  final String detail;
  const SentCheck({required this.key, required this.state, required this.label, required this.detail});

  bool get ok => state == 'ok';
  bool get missing => state == 'missing';

  factory SentCheck.fromJson(Map<String, dynamic> j) => SentCheck(key: j['key'] as String, state: j['state'] as String, label: j['label'] as String? ?? '', detail: j['detail'] as String? ?? '');
}

class SentPiece {
  final String id;
  final int position;
  final String title;
  final String brief;
  final String role;
  final String madeOn;
  final String liveLink;
  final String processLink;
  final List<SentFile> finished;
  final List<SentFile> howMade;
  final List<SentCheck> checks;
  const SentPiece({required this.id, required this.position, required this.title, required this.brief, required this.role, required this.madeOn, required this.liveLink, required this.processLink, required this.finished, required this.howMade, required this.checks});

  String get displayTitle => title.trim().isEmpty ? 'Untitled piece' : title.trim();

  factory SentPiece.fromJson(Map<String, dynamic> j) => SentPiece(
    id: j['id'] as String,
    position: (j['position'] as num?)?.toInt() ?? 0,
    title: j['title'] as String? ?? '',
    brief: j['brief'] as String? ?? '',
    role: j['role'] as String? ?? '',
    madeOn: j['madeOn'] as String? ?? '',
    liveLink: j['liveLink'] as String? ?? '',
    processLink: j['processLink'] as String? ?? '',
    finished: [for (final f in _maps(j['finished'])) SentFile.fromJson(f)],
    howMade: [for (final f in _maps(j['howMade'])) SentFile.fromJson(f)],
    checks: [for (final c in _maps(j['checks'])) SentCheck.fromJson(c)],
  );
}

/// One requirement of the pack: what was asked, whether it was met, and why it is asked for.
class SentRequirement {
  final String key;
  final String label;
  final bool done;
  final String? why;
  const SentRequirement({required this.key, required this.label, required this.done, this.why});

  factory SentRequirement.fromJson(Map<String, dynamic> j) => SentRequirement(key: j['key'] as String, label: j['label'] as String, done: j['done'] as bool? ?? false, why: j['why'] as String?);
}

class SentWork {
  final String id;
  final String skillKey;
  final String skillLabel;
  final String status;
  final DateTime? submittedAt;
  /// complete, complete_with_advice or gaps.
  final String verdict;
  final String headline;
  final String detail;
  final String howMadePrompt;
  final List<String> howMadeOptions;
  final List<SentRequirement> requirements;
  final List<SentPiece> pieces;
  final List<SentFile> walkthrough;
  final bool ownWork;
  final bool aiUsed;
  final String? aiNote;
  const SentWork({
    required this.id,
    required this.skillKey,
    required this.skillLabel,
    required this.status,
    required this.submittedAt,
    required this.verdict,
    required this.headline,
    required this.detail,
    required this.howMadePrompt,
    required this.howMadeOptions,
    required this.requirements,
    required this.pieces,
    required this.walkthrough,
    required this.ownWork,
    required this.aiUsed,
    required this.aiNote,
  });

  factory SentWork.fromJson(Map<String, dynamic> json) {
    final j = json['work'] as Map<String, dynamic>;
    final summary = j['summary'] as Map<String, dynamic>? ?? const {};
    final howMade = j['howMade'] as Map<String, dynamic>?;
    final decl = j['declaration'] as Map<String, dynamic>? ?? const {};
    return SentWork(
      id: j['id'] as String,
      skillKey: j['skillKey'] as String? ?? '',
      skillLabel: j['skillLabel'] as String? ?? '',
      status: j['status'] as String? ?? '',
      submittedAt: _date(j['submittedAt']),
      verdict: summary['verdict'] as String? ?? 'complete',
      headline: summary['headline'] as String? ?? '',
      detail: summary['detail'] as String? ?? '',
      howMadePrompt: howMade?['prompt'] as String? ?? '',
      howMadeOptions: [for (final o in (howMade?['options'] as List? ?? const [])) o as String],
      requirements: [for (final r in _maps(j['requirements'])) SentRequirement.fromJson(r)],
      pieces: [for (final p in _maps(j['pieces'])) SentPiece.fromJson(p)],
      walkthrough: [for (final f in _maps(j['walkthrough'])) SentFile.fromJson(f)],
      ownWork: decl['ownWork'] as bool? ?? false,
      aiUsed: decl['aiUsed'] as bool? ?? false,
      aiNote: decl['aiNote'] as String?,
    );
  }
}

/// What a link looks like when it is opened, the way a chat app unfurls one. [ok] false means it couldn't be read, and
/// [reason] says why in words the person can act on.
class LinkPreview {
  final bool ok;
  final String url;
  final String? host;
  final String? reason;
  final String? title;
  final String? description;
  final String? image;
  final String? siteName;
  final String? favicon;
  /// page, or file when the link goes straight to a download.
  final String kind;
  const LinkPreview({required this.ok, required this.url, this.host, this.reason, this.title, this.description, this.image, this.siteName, this.favicon, this.kind = 'page'});

  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    final j = json['preview'] as Map<String, dynamic>;
    return LinkPreview(
      ok: j['ok'] as bool? ?? false,
      url: j['url'] as String? ?? '',
      host: j['host'] as String?,
      reason: j['reason'] as String?,
      title: j['title'] as String?,
      description: j['description'] as String?,
      image: j['image'] as String?,
      siteName: j['siteName'] as String?,
      favicon: j['favicon'] as String?,
      kind: j['kind'] as String? ?? 'page',
    );
  }
}
