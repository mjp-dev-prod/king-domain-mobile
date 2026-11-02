// Proving a skill, as the server describes it (backend src/submissions.js and src/user/submissionRoutes.js;
// PRD §4.3, decisions D5 to D9).

/// Where a person stands in one skill.
enum SkillState { notStarted, draft, inReview, verified, notYet, restricted }

enum SubmissionStatus { draft, authenticity, review, verified, notYet, removed }

enum FileRole { output, working, draft, walkthrough }

SkillState _parseState(String? v) => SkillState.values.where((s) => s.name == v).firstOrNull ?? SkillState.notStarted;
SubmissionStatus _parseStatus(String? v) => SubmissionStatus.values.where((s) => s.name == v).firstOrNull ?? SubmissionStatus.draft;
FileRole _parseRole(String? v) => FileRole.values.where((s) => s.name == v).firstOrNull ?? FileRole.output;
DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

/// A ban or a period out of one skill.
class SkillRestriction {
  final String kind;
  final DateTime? until;
  final String reason;
  const SkillRestriction({required this.kind, required this.until, required this.reason});

  bool get permanent => until == null;

  factory SkillRestriction.fromJson(Map<String, dynamic> j) =>
      SkillRestriction(kind: j['kind'] as String, until: _date(j['until']), reason: (j['reason'] as String?) ?? '');
}

class SkillHubEntry {
  final String skillKey;
  final String label;
  final String category;
  final SkillState state;
  final String? currentSubmissionId;
  final int attempts;
  final SkillRestriction? restriction;
  final bool rubricDraft;

  const SkillHubEntry({
    required this.skillKey,
    required this.label,
    required this.category,
    required this.state,
    required this.currentSubmissionId,
    required this.attempts,
    required this.restriction,
    required this.rubricDraft,
  });

  factory SkillHubEntry.fromJson(Map<String, dynamic> j) => SkillHubEntry(
    skillKey: j['skillKey'] as String,
    label: j['label'] as String,
    category: j['category'] as String,
    state: _parseState(j['state'] as String?),
    currentSubmissionId: j['currentSubmissionId'] as String?,
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    restriction: j['restriction'] == null ? null : SkillRestriction.fromJson(j['restriction'] as Map<String, dynamic>),
    rubricDraft: (j['rubricDraft'] as bool?) ?? true,
  );
}

class SkillHub {
  final List<SkillHubEntry> skills;
  final bool uploadsAvailable;
  const SkillHub({required this.skills, required this.uploadsAvailable});

  factory SkillHub.fromJson(Map<String, dynamic> j) => SkillHub(
    skills: [for (final s in j['skills'] as List) SkillHubEntry.fromJson(s as Map<String, dynamic>)],
    uploadsAvailable: (j['uploadsAvailable'] as bool?) ?? false,
  );
}

class SubmissionFile {
  final String id;
  final FileRole role;
  final String? pieceId;
  final String name;
  final String contentType;
  final int sizeBytes;
  final bool ready;

  const SubmissionFile({required this.id, required this.role, required this.pieceId, required this.name, required this.contentType, required this.sizeBytes, required this.ready});

  factory SubmissionFile.fromJson(Map<String, dynamic> j) => SubmissionFile(
    id: j['id'] as String,
    role: _parseRole(j['role'] as String?),
    pieceId: j['pieceId'] as String?,
    name: j['name'] as String,
    contentType: j['contentType'] as String,
    sizeBytes: (j['sizeBytes'] as num).toInt(),
    ready: j['status'] == 'ready',
  );
}

class SubmissionPiece {
  final String id;
  final int position;
  final String title;
  final String brief;
  final String role;
  final String madeOn;
  final String liveLink;
  /// A link that shows how it was made (a repository, a Figma file, a shared document).
  final String processLink;
  final List<SubmissionFile> files;

  const SubmissionPiece({required this.id, required this.position, required this.title, required this.brief, required this.role, required this.madeOn, required this.liveLink, this.processLink = '', required this.files});

  factory SubmissionPiece.fromJson(Map<String, dynamic> j) => SubmissionPiece(
    id: j['id'] as String,
    position: (j['position'] as num).toInt(),
    title: (j['title'] as String?) ?? '',
    brief: (j['brief'] as String?) ?? '',
    role: (j['role'] as String?) ?? '',
    madeOn: (j['madeOn'] as String?) ?? '',
    liveLink: (j['liveLink'] as String?) ?? '',
    processLink: (j['processLink'] as String?) ?? '',
    files: [for (final f in (j['files'] as List? ?? const [])) SubmissionFile.fromJson(f as Map<String, dynamic>)],
  );

  bool get detailsDone => title.trim().isNotEmpty && brief.trim().isNotEmpty && role.trim().isNotEmpty && madeOn.trim().isNotEmpty;
  List<SubmissionFile> filesOf(FileRole r) => [for (final f in files) if (f.role == r) f];
  String get displayTitle => title.trim().isEmpty ? 'Untitled piece' : title.trim();
}

class ReadinessItem {
  final String key;
  final String label;
  final bool done;
  const ReadinessItem({required this.key, required this.label, required this.done});

  factory ReadinessItem.fromJson(Map<String, dynamic> j) => ReadinessItem(key: j['key'] as String, label: j['label'] as String, done: j['done'] as bool);
}

class RubricLine {
  final String key;
  final String label;
  final String looksLike;
  const RubricLine({required this.key, required this.label, required this.looksLike});

  factory RubricLine.fromJson(Map<String, dynamic> j) => RubricLine(key: j['key'] as String, label: j['label'] as String, looksLike: j['looksLike'] as String);
}

/// A line the reviewers scored 2 or lower, with the lowest score it got.
class ResultLine {
  final String label;
  final String looksLike;
  final int score;
  const ResultLine({required this.label, required this.looksLike, required this.score});

  factory ResultLine.fromJson(Map<String, dynamic> j) => ResultLine(label: j['label'] as String, looksLike: j['looksLike'] as String, score: (j['score'] as num).toInt());
}

/// The outcome of an attempt. [kind] says where it ended: 'review' (scored by reviewers), 'authenticity'
/// (the check before review) or 'removed' (a ban).
class SubmissionResult {
  final SubmissionStatus outcome;
  final String? kind;
  final List<ResultLine> lines;
  final List<String> comments;
  final String? note;
  final DateTime? restrictedUntil;

  const SubmissionResult({required this.outcome, this.kind, this.lines = const [], this.comments = const [], this.note, this.restrictedUntil});

  factory SubmissionResult.fromJson(Map<String, dynamic> j) => SubmissionResult(
    outcome: _parseStatus(j['outcome'] as String?),
    kind: j['kind'] as String?,
    lines: [for (final l in (j['lines'] as List? ?? const [])) ResultLine.fromJson(l as Map<String, dynamic>)],
    comments: [for (final c in (j['comments'] as List? ?? const [])) c as String],
    note: j['note'] as String?,
    restrictedUntil: _date(j['restrictedUntil']),
  );
}

/// What each kind of file may be, as the server states it, so the app can refuse early with a clear message.
class FileLimit {
  final int maxBytes;
  final List<String> types;
  const FileLimit({required this.maxBytes, required this.types});
}

class SubmissionDetail {
  final String id;
  final String skillKey;
  final String skillLabel;
  final SubmissionStatus status;
  final bool declaredOwnWork;
  final bool aiUsed;
  final String? aiNote;
  final bool termsAccepted;
  final bool termsNeeded;
  final List<String> terms;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final List<SubmissionPiece> pieces;
  final List<SubmissionFile> walkthrough;
  final List<ReadinessItem> readiness;
  final bool ready;
  final int minPieces;
  final int maxPieces;
  final Map<FileRole, FileLimit> limits;
  final List<RubricLine> rubric;
  final bool rubricDraft;
  final SubmissionResult? result;
  /// What counts as "how it was made" for this skill, in words its people recognise (decision 2026-11-02).
  final String howMadePrompt;
  final List<String> howMadeOptions;

  const SubmissionDetail({
    required this.id,
    required this.skillKey,
    required this.skillLabel,
    required this.status,
    required this.declaredOwnWork,
    required this.aiUsed,
    required this.aiNote,
    required this.termsAccepted,
    required this.termsNeeded,
    required this.terms,
    required this.submittedAt,
    required this.decidedAt,
    required this.pieces,
    required this.walkthrough,
    required this.readiness,
    required this.ready,
    required this.minPieces,
    required this.maxPieces,
    required this.limits,
    required this.rubric,
    required this.rubricDraft,
    required this.result,
    this.howMadePrompt = 'Show how it was made. Any one of these, for at least one piece.',
    this.howMadeOptions = const ['A screenshot of the work open in the tool you used', 'An earlier version or your notes', 'A link to the project, if it has a history'],
  });

  factory SubmissionDetail.fromJson(Map<String, dynamic> j) {
    final limits = j['limits'] as Map<String, dynamic>;
    final rubric = j['rubric'] as Map<String, dynamic>?;
    final readiness = j['readiness'] as Map<String, dynamic>;
    return SubmissionDetail(
      id: j['id'] as String,
      skillKey: j['skillKey'] as String,
      skillLabel: j['skillLabel'] as String,
      status: _parseStatus(j['status'] as String?),
      declaredOwnWork: (j['declaredOwnWork'] as bool?) ?? false,
      aiUsed: (j['aiUsed'] as bool?) ?? false,
      aiNote: j['aiNote'] as String?,
      termsAccepted: (j['termsAccepted'] as bool?) ?? false,
      termsNeeded: (j['termsNeeded'] as bool?) ?? false,
      terms: [for (final t in (j['terms'] as List? ?? const [])) t as String],
      submittedAt: _date(j['submittedAt']),
      decidedAt: _date(j['decidedAt']),
      pieces: [for (final p in j['pieces'] as List) SubmissionPiece.fromJson(p as Map<String, dynamic>)],
      walkthrough: [for (final f in (j['walkthrough'] as List? ?? const [])) SubmissionFile.fromJson(f as Map<String, dynamic>)],
      readiness: [for (final i in readiness['items'] as List) ReadinessItem.fromJson(i as Map<String, dynamic>)],
      ready: readiness['ready'] as bool,
      minPieces: (limits['minPieces'] as num).toInt(),
      maxPieces: (limits['maxPieces'] as num).toInt(),
      limits: {
        for (final role in FileRole.values)
          if ((limits['files'] as Map?)?[role.name] case final Map f)
            role: FileLimit(maxBytes: (f['maxBytes'] as num).toInt(), types: [for (final t in f['types'] as List) t as String]),
      },
      rubric: [for (final l in (rubric?['lines'] as List? ?? const [])) RubricLine.fromJson(l as Map<String, dynamic>)],
      rubricDraft: (rubric?['draft'] as bool?) ?? true,
      result: j['result'] == null ? null : SubmissionResult.fromJson(j['result'] as Map<String, dynamic>),
      howMadePrompt: ((j['howMade'] as Map?)?['prompt'] as String?) ?? 'Show how it was made. Any one of these, for at least one piece.',
      howMadeOptions: [
        for (final o in (((j['howMade'] as Map?)?['options'] as List?) ?? const ['A screenshot of the work open in the tool you used', 'An earlier version or your notes', 'A link to the project, if it has a history'])) o as String,
      ],
    );
  }

  List<SubmissionFile> get allFiles => [for (final p in pieces) ...p.files, ...walkthrough];
  bool get hasWalkthrough => walkthrough.any((f) => f.ready);
}

/// One earlier attempt in a skill's history.
class HistoryEntry {
  final String id;
  final SubmissionStatus status;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final SubmissionResult? result;
  const HistoryEntry({required this.id, required this.status, required this.submittedAt, required this.decidedAt, required this.result});

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    id: j['id'] as String,
    status: _parseStatus(j['status'] as String?),
    submittedAt: _date(j['submittedAt']),
    decidedAt: _date(j['decidedAt']),
    result: j['result'] == null ? null : SubmissionResult.fromJson({'outcome': j['status'], ...(j['result'] as Map<String, dynamic>)}),
  );
}

/// A link to PUT a file to, from POST .../files.
class UploadTicket {
  final SubmissionFile file;
  final String url;
  final Map<String, String> headers;
  const UploadTicket({required this.file, required this.url, required this.headers});

  factory UploadTicket.fromJson(Map<String, dynamic> j) {
    final upload = j['upload'] as Map<String, dynamic>;
    return UploadTicket(
      file: SubmissionFile.fromJson(j['file'] as Map<String, dynamic>),
      url: upload['url'] as String,
      headers: {for (final e in (upload['headers'] as Map<String, dynamic>).entries) e.key: e.value as String},
    );
  }
}
