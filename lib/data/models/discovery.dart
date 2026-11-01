// Discovery as the server describes it (backend src/discovery.js, src/briefs.js and the routes that serve them;
// PRD §4.6, decisions D21 to D25). No score and no rank anywhere: facts only.
import 'job.dart';
import 'reputation.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);
Map<String, dynamic> _map(Object? v) =>
    (v as Map?)?.cast<String, dynamic>() ?? const {};
List<Map<String, dynamic>> _maps(Object? v) => [
  for (final e in (v as List? ?? const [])) (e as Map).cast<String, dynamic>(),
];

// ── The feed ─────────────────────────────────────────────

/// What a talent filters the job feed by (PRD §3.1 step 7). Everything is optional.
class FeedFilters {
  final String query;
  final Set<String> skills;
  final Set<JobType> types;

  /// null = any, 'local' = naira, 'international' = dollars.
  final String? market;
  final int? budgetMin;
  final int? budgetMax;
  final int? deliveryDaysMax;
  final bool verifiedClient;
  final bool fewApplicants;

  /// Put jobs in the talent's verified skills first.
  final bool forYou;

  const FeedFilters({
    this.query = '',
    this.skills = const {},
    this.types = const {},
    this.market,
    this.budgetMin,
    this.budgetMax,
    this.deliveryDaysMax,
    this.verifiedClient = false,
    this.fewApplicants = false,
    this.forYou = true,
  });

  FeedFilters copyWith({
    String? query,
    Set<String>? skills,
    Set<JobType>? types,
    Object? market = _keep,
    Object? budgetMin = _keep,
    Object? budgetMax = _keep,
    Object? deliveryDaysMax = _keep,
    bool? verifiedClient,
    bool? fewApplicants,
    bool? forYou,
  }) => FeedFilters(
    query: query ?? this.query,
    skills: skills ?? this.skills,
    types: types ?? this.types,
    market: identical(market, _keep) ? this.market : market as String?,
    budgetMin: identical(budgetMin, _keep) ? this.budgetMin : budgetMin as int?,
    budgetMax: identical(budgetMax, _keep) ? this.budgetMax : budgetMax as int?,
    deliveryDaysMax: identical(deliveryDaysMax, _keep)
        ? this.deliveryDaysMax
        : deliveryDaysMax as int?,
    verifiedClient: verifiedClient ?? this.verifiedClient,
    fewApplicants: fewApplicants ?? this.fewApplicants,
    forYou: forYou ?? this.forYou,
  );

  static const _keep = Object();

  /// Filters other than the "for you" ordering, which is not a filter. Drives the badge and "clear".
  int get activeCount =>
      (query.trim().isEmpty ? 0 : 1) +
      (skills.isEmpty ? 0 : 1) +
      (types.isEmpty ? 0 : 1) +
      (market == null ? 0 : 1) +
      (budgetMin == null && budgetMax == null ? 0 : 1) +
      (deliveryDaysMax == null ? 0 : 1) +
      (verifiedClient ? 1 : 0) +
      (fewApplicants ? 1 : 0);

  bool get isEmpty => activeCount == 0;

  Map<String, String> toQuery({String? cursor, int limit = 20}) => {
    'limit': '$limit',
    if (forYou) 'forYou': 'true',
    if (query.trim().isNotEmpty) 'q': query.trim(),
    if (skills.isNotEmpty) 'skill': skills.join(','),
    if (types.isNotEmpty) 'type': types.map((t) => t.name).join(','),
    'market': ?market,
    if (budgetMin != null) 'budgetMin': '$budgetMin',
    if (budgetMax != null) 'budgetMax': '$budgetMax',
    if (deliveryDaysMax != null) 'deliveryDaysMax': '$deliveryDaysMax',
    if (verifiedClient) 'verifiedClient': 'true',
    if (fewApplicants) 'fewApplicants': 'true',
    'cursor': ?cursor,
  };

  /// What a saved search stores, in the shape the server matches new jobs against.
  Map<String, dynamic> toSavedFilters() => {
    if (skills.isNotEmpty) 'skillKeys': skills.toList(),
    if (types.isNotEmpty) 'jobTypes': [for (final t in types) t.name],
    if (market == 'local') 'currency': 'NGN',
    if (market == 'international') 'currency': 'USD',
    if (budgetMin != null) 'budgetMin': budgetMin,
    if (budgetMax != null) 'budgetMax': budgetMax,
    if (deliveryDaysMax != null) 'deliveryDaysMax': deliveryDaysMax,
    if (query.trim().isNotEmpty) 'query': query.trim(),
  };

  @override
  bool operator ==(Object other) =>
      other is FeedFilters &&
      other.query == query &&
      other.skills.length == skills.length &&
      other.skills.containsAll(skills) &&
      other.types.length == types.length &&
      other.types.containsAll(types) &&
      other.market == market &&
      other.budgetMin == budgetMin &&
      other.budgetMax == budgetMax &&
      other.deliveryDaysMax == deliveryDaysMax &&
      other.verifiedClient == verifiedClient &&
      other.fewApplicants == fewApplicants &&
      other.forYou == forYou;

  @override
  int get hashCode => Object.hash(
    query,
    Object.hashAllUnordered(skills),
    Object.hashAllUnordered(types),
    market,
    budgetMin,
    budgetMax,
    deliveryDaysMax,
    verifiedClient,
    fewApplicants,
    forYou,
  );
}

class FeedPage {
  final List<Job> jobs;
  final String? nextCursor;
  const FeedPage({required this.jobs, required this.nextCursor});
}

class SavedSearch {
  final String id;
  final String name;
  final Map<String, dynamic> filters;
  final bool alerts;
  const SavedSearch({
    required this.id,
    required this.name,
    required this.filters,
    required this.alerts,
  });

  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
    id: j['id'] as String,
    name: j['name'] as String,
    filters: _map(j['filters']),
    alerts: j['alerts'] as bool? ?? true,
  );

  /// A readable summary of what the search looks for.
  String get summary {
    final parts = <String>[];
    final skills = (filters['skillKeys'] as List?)?.length ?? 0;
    if (skills > 0) parts.add('$skills skill${skills == 1 ? '' : 's'}');
    final types = (filters['jobTypes'] as List?)?.cast<String>() ?? const [];
    if (types.isNotEmpty) {
      parts.add(
        types
            .map(
              (t) =>
                  JobType.values.where((v) => v.name == t).firstOrNull?.label ??
                  t,
            )
            .join(', '),
      );
    }
    if (filters['currency'] != null) {
      parts.add(filters['currency'] == 'USD' ? 'dollars' : 'naira');
    }
    if (filters['budgetMin'] != null || filters['budgetMax'] != null) {
      parts.add(
        'budget ${filters['budgetMin'] ?? 0} to ${filters['budgetMax'] ?? 'any'}',
      );
    }
    if (filters['deliveryDaysMax'] != null) {
      parts.add('within ${filters['deliveryDaysMax']} days');
    }
    if (filters['query'] != null) parts.add('"${filters['query']}"');
    return parts.isEmpty ? 'Everything' : parts.join(' · ');
  }
}

// ── The post-a-job form ──────────────────────────────────

enum BriefKind { text, int, choice, milestones }

class BriefField {
  final String key;
  final String label;
  final BriefKind kind;
  final bool required;
  final int? min;
  final int? max;
  final List<String> options;

  const BriefField({
    required this.key,
    required this.label,
    required this.kind,
    required this.required,
    this.min,
    this.max,
    this.options = const [],
  });

  factory BriefField.fromJson(Map<String, dynamic> j) => BriefField(
    key: j['key'] as String,
    label: j['label'] as String,
    kind:
        BriefKind.values.where((k) => k.name == j['kind']).firstOrNull ??
        BriefKind.text,
    required: j['required'] as bool? ?? true,
    min: (j['min'] as num?)?.toInt(),
    max: (j['max'] as num?)?.toInt(),
    options: [for (final o in (j['options'] as List? ?? const [])) o as String],
  );
}

class BriefSpec {
  final List<BriefField> fields;
  const BriefSpec(this.fields);
  factory BriefSpec.fromJson(Map<String, dynamic> j) =>
      BriefSpec([for (final f in _maps(j['fields'])) BriefField.fromJson(f)]);
}

/// Words for the usage-rights choices (the server sends the codes).
String usageRightsLabel(String code) => switch (code) {
  'none' => 'No use beyond me looking at it',
  'organic' => 'Posting on my own pages',
  'paid30' => 'Paid ads for 30 days',
  'paid90' => 'Paid ads for 90 days',
  'fullOnPayment' => 'Everything, once I have paid in full',
  _ => code,
};

// ── Talents ──────────────────────────────────────────────

class TalentSkill {
  final String skillKey;
  final String label;
  final DateTime? verifiedAt;
  const TalentSkill({
    required this.skillKey,
    required this.label,
    required this.verifiedAt,
  });
  factory TalentSkill.fromJson(Map<String, dynamic> j) => TalentSkill(
    skillKey: j['skillKey'] as String,
    label: j['label'] as String,
    verifiedAt: _date(j['verifiedAt']),
  );
}

/// The facts a client weighs a talent on: never a score, never a rank (D23).
class TalentCard {
  final String id;
  final String fullName;
  final String? photoUrl;
  final String? headline;
  final List<TalentSkill> verifiedSkills;
  final String? regionText;
  final String? educationText;
  final int completedJobs;
  final bool newOnKingDomain;

  /// today, this_week, this_month or earlier.
  final String lastActive;
  final bool identityVerified;
  final bool saved;

  /// "within an hour" and so on: the median of real first replies, shown only after 3 conversations (D24).
  final String? responseTime;

  const TalentCard({
    required this.id,
    required this.fullName,
    this.photoUrl,
    this.headline,
    required this.verifiedSkills,
    this.regionText,
    this.educationText,
    required this.completedJobs,
    required this.newOnKingDomain,
    required this.lastActive,
    required this.identityVerified,
    required this.saved,
    this.responseTime,
  });

  factory TalentCard.fromJson(Map<String, dynamic> j) {
    final r = j['region'] as Map<String, dynamic>?;
    final e = j['education'] as Map<String, dynamic>?;
    return TalentCard(
      id: j['id'] as String,
      fullName: j['fullName'] as String,
      photoUrl: j['photoUrl'] as String?,
      headline: j['headline'] as String?,
      verifiedSkills: [
        for (final s in _maps(j['verifiedSkills'])) TalentSkill.fromJson(s),
      ],
      regionText: r == null
          ? null
          : [
              r['city'],
              r['state'],
              r['country'],
            ].where((p) => p != null && '$p'.isNotEmpty).join(', '),
      educationText: e == null ? null : _educationText(e),
      completedJobs: (j['completedJobs'] as num?)?.toInt() ?? 0,
      newOnKingDomain: j['newOnKingDomain'] as bool? ?? false,
      lastActive: j['lastActive'] as String? ?? 'earlier',
      identityVerified: j['identityVerified'] as bool? ?? false,
      saved: j['saved'] as bool? ?? false,
      responseTime: (j['responseTime'] as Map?)?['label'] as String?,
    );
  }

  String get lastActiveText => switch (lastActive) {
    'today' => 'Active today',
    'this_week' => 'Active this week',
    'this_month' => 'Active this month',
    _ => 'Active a while ago',
  };

  TalentCard copyWith({bool? saved}) => TalentCard(
    id: id,
    fullName: fullName,
    photoUrl: photoUrl,
    headline: headline,
    verifiedSkills: verifiedSkills,
    regionText: regionText,
    educationText: educationText,
    completedJobs: completedJobs,
    newOnKingDomain: newOnKingDomain,
    lastActive: lastActive,
    identityVerified: identityVerified,
    saved: saved ?? this.saved,
    responseTime: responseTime,
  );
}

String _educationText(Map<String, dynamic> e) {
  final kind = switch (e['kind']) {
    'student' => 'Student',
    'graduate' => 'Graduate',
    'trained' => 'Trained',
    'selfTaught' => 'Self-taught',
    _ => '',
  };
  final where = [
    e['school'],
    e['detail'],
  ].where((p) => p != null && '$p'.isNotEmpty).join(', ');
  return where.isEmpty ? kind : '$kind · $where';
}

class WorkFile {
  final String name;
  final String contentType;
  final String? url;
  const WorkFile({
    required this.name,
    required this.contentType,
    required this.url,
  });
  factory WorkFile.fromJson(Map<String, dynamic> j) => WorkFile(
    name: j['name'] as String,
    contentType: j['contentType'] as String,
    url: j['url'] as String?,
  );
}

/// One piece of verified work: what it was, the person's part, and links to look at it.
class WorkPiece {
  final String id;
  final String title;
  final String brief;
  final String role;
  final String madeOn;
  final String? liveLink;
  final List<WorkFile> files;
  const WorkPiece({
    required this.id,
    required this.title,
    required this.brief,
    required this.role,
    required this.madeOn,
    required this.liveLink,
    required this.files,
  });

  factory WorkPiece.fromJson(Map<String, dynamic> j) => WorkPiece(
    id: j['id'] as String,
    title: (j['title'] as String?) ?? '',
    brief: (j['brief'] as String?) ?? '',
    role: (j['role'] as String?) ?? '',
    madeOn: (j['madeOn'] as String?) ?? '',
    liveLink: j['liveLink'] as String?,
    files: [for (final f in _maps(j['files'])) WorkFile.fromJson(f)],
  );
}

class VerifiedWork {
  final String skillKey;
  final String skillLabel;
  final DateTime? verifiedAt;
  final List<WorkPiece> pieces;
  const VerifiedWork({
    required this.skillKey,
    required this.skillLabel,
    required this.verifiedAt,
    required this.pieces,
  });

  factory VerifiedWork.fromJson(Map<String, dynamic> j) => VerifiedWork(
    skillKey: j['skillKey'] as String,
    skillLabel: j['skillLabel'] as String,
    verifiedAt: _date(j['verifiedAt']),
    pieces: [for (final p in _maps(j['pieces'])) WorkPiece.fromJson(p)],
  );
}

class TalentProfileView {
  final TalentCard card;
  final String? bio;
  final List<VerifiedWork> work;
  /// Plain counts, visible reviews with their facts, and Proven levels. Never a score (D29).
  final TalentReputation reputation;
  const TalentProfileView({
    required this.card,
    required this.bio,
    required this.work,
    this.reputation = const TalentReputation(),
  });

  factory TalentProfileView.fromJson(Map<String, dynamic> j) {
    final t = j['talent'] as Map<String, dynamic>;
    return TalentProfileView(
      card: TalentCard.fromJson(t),
      bio: t['bio'] as String?,
      work: [for (final w in _maps(j['work'])) VerifiedWork.fromJson(w)],
      reputation: j['reputation'] == null ? const TalentReputation() : TalentReputation.fromJson(j['reputation'] as Map<String, dynamic>),
    );
  }
}

class TalentPage {
  final List<TalentCard> talents;
  final String? nextCursor;
  const TalentPage({required this.talents, required this.nextCursor});
}

/// Filters when a client browses talents.
class TalentFilters {
  final String? skill;
  final String? state;
  final String? education;
  final bool hasCompleted;
  final String query;
  const TalentFilters({
    this.skill,
    this.state,
    this.education,
    this.hasCompleted = false,
    this.query = '',
  });

  TalentFilters copyWith({
    Object? skill = _k,
    Object? state = _k,
    Object? education = _k,
    bool? hasCompleted,
    String? query,
  }) => TalentFilters(
    skill: identical(skill, _k) ? this.skill : skill as String?,
    state: identical(state, _k) ? this.state : state as String?,
    education: identical(education, _k) ? this.education : education as String?,
    hasCompleted: hasCompleted ?? this.hasCompleted,
    query: query ?? this.query,
  );
  static const _k = Object();

  int get activeCount =>
      (skill == null ? 0 : 1) +
      (state == null ? 0 : 1) +
      (education == null ? 0 : 1) +
      (hasCompleted ? 1 : 0) +
      (query.trim().isEmpty ? 0 : 1);

  Map<String, String> toQuery({String? cursor}) => {
    'limit': '20',
    'skill': ?skill,
    'state': ?state,
    'education': ?education,
    if (hasCompleted) 'hasCompleted': 'true',
    if (query.trim().isNotEmpty) 'q': query.trim(),
    'cursor': ?cursor,
  };

  @override
  bool operator ==(Object other) =>
      other is TalentFilters &&
      other.skill == skill &&
      other.state == state &&
      other.education == education &&
      other.hasCompleted == hasCompleted &&
      other.query == query;
  @override
  int get hashCode => Object.hash(skill, state, education, hasCompleted, query);
}

// ── Job detail extras ────────────────────────────────────

class ClientRecord {
  final DateTime? memberSince;
  final bool identityVerified;
  final int jobsPosted;
  final int jobsHired;
  final int jobsCompleted;
  final List<({String currency, double amount})> paidOut;
  /// What talents said about this client, and how they behave: plain counts (D19).
  final ClientReputation reputation;
  const ClientRecord({
    this.reputation = const ClientReputation(),
    this.memberSince,
    required this.identityVerified,
    required this.jobsPosted,
    required this.jobsHired,
    required this.jobsCompleted,
    required this.paidOut,
  });

  factory ClientRecord.fromJson(Map<String, dynamic> j) => ClientRecord(
    reputation: j['reputation'] == null ? const ClientReputation() : ClientReputation.fromJson(j['reputation'] as Map<String, dynamic>),
    memberSince: _date(j['memberSince']),
    identityVerified: j['identityVerified'] as bool? ?? false,
    jobsPosted: (j['jobsPosted'] as num?)?.toInt() ?? 0,
    jobsHired: (j['jobsHired'] as num?)?.toInt() ?? 0,
    jobsCompleted: (j['jobsCompleted'] as num?)?.toInt() ?? 0,
    paidOut: [
      for (final p in _maps(j['paidOut']))
        (
          currency: p['currency'] as String,
          amount: (p['amount'] as num).toDouble(),
        ),
    ],
  );
}

class InvitationInfo {
  final String id;
  final DateTime expiresAt;
  final String? message;
  const InvitationInfo({
    required this.id,
    required this.expiresAt,
    this.message,
  });
  factory InvitationInfo.fromJson(Map<String, dynamic> j) => InvitationInfo(
    id: j['id'] as String,
    expiresAt: DateTime.parse(j['expiresAt'] as String),
    message: j['message'] as String?,
  );
}

/// GET /jobs/:id: the job, the client's facts, and any invitation to this talent.
class JobDetailData {
  final Job job;
  final ClientRecord clientRecord;
  final InvitationInfo? invitation;
  const JobDetailData({
    required this.job,
    required this.clientRecord,
    required this.invitation,
  });

  factory JobDetailData.fromJson(Map<String, dynamic> j) => JobDetailData(
    job: Job.fromJson(j['job'] as Map<String, dynamic>),
    clientRecord: ClientRecord.fromJson(_map(j['clientRecord'])),
    invitation: j['invitation'] == null
        ? null
        : InvitationInfo.fromJson(j['invitation'] as Map<String, dynamic>),
  );
}

// ── Invitations and the shortlist ────────────────────────

class InvitationItem {
  final String id;

  /// pending, accepted, declined or expired.
  final String status;
  final String? message;
  final DateTime expiresAt;
  final String from;
  final Job job;
  const InvitationItem({
    required this.id,
    required this.status,
    required this.message,
    required this.expiresAt,
    required this.from,
    required this.job,
  });

  factory InvitationItem.fromJson(Map<String, dynamic> j) => InvitationItem(
    id: j['id'] as String,
    status: j['status'] as String,
    message: j['message'] as String?,
    expiresAt: DateTime.parse(j['expiresAt'] as String),
    from: j['from'] as String? ?? 'A client',
    job: Job.fromJson(j['job'] as Map<String, dynamic>),
  );

  bool get open => status == 'pending' && expiresAt.isAfter(DateTime.now());
}

class ShortlistPromise {
  /// "usually within N hours", the 90th percentile of the last 20 shortlists; null until there is enough to say.
  final int? hours;
  final int basedOn;
  const ShortlistPromise({required this.hours, required this.basedOn});
  factory ShortlistPromise.fromJson(Map<String, dynamic> j) => ShortlistPromise(
    hours: (j['hours'] as num?)?.toInt(),
    basedOn: (j['basedOn'] as num?)?.toInt() ?? 0,
  );
}

class ShortlistPick {
  final String reason;
  final TalentCard talent;
  const ShortlistPick({required this.reason, required this.talent});
}

class ShortlistRequestView {
  final String id;
  final String skillLabel;
  final String status;
  final DateTime requestedAt;
  final DateTime? sentAt;
  final List<ShortlistPick> picks;
  const ShortlistRequestView({
    required this.id,
    required this.skillLabel,
    required this.status,
    required this.requestedAt,
    required this.sentAt,
    required this.picks,
  });

  factory ShortlistRequestView.fromJson(Map<String, dynamic> j) =>
      ShortlistRequestView(
        id: j['id'] as String,
        skillLabel: j['skillLabel'] as String,
        status: j['status'] as String,
        requestedAt: DateTime.parse(j['requestedAt'] as String),
        sentAt: _date(j['sentAt']),
        picks: [
          for (final p in _maps(j['shortlist']))
            ShortlistPick(
              reason: p['reason'] as String,
              talent: TalentCard.fromJson(_map(p['talent'])),
            ),
        ],
      );

  bool get waiting => status == 'requested' || status == 'building';
}

/// A client may want this talent: "are you available?" (D24).
class ShortlistAsk {
  final String id;
  final DateTime askedAt;
  final bool? available;
  final String skillLabel;
  final String budgetText;
  const ShortlistAsk({
    required this.id,
    required this.askedAt,
    required this.available,
    required this.skillLabel,
    required this.budgetText,
  });

  factory ShortlistAsk.fromJson(Map<String, dynamic> j) => ShortlistAsk(
    id: j['id'] as String,
    askedAt: DateTime.parse(j['askedAt'] as String),
    available: j['available'] as bool?,
    skillLabel: j['skillLabel'] as String,
    budgetText: '${j['currency'] == 'USD' ? r'$' : '₦'}${j['budget']}',
  );
}

// ── Applicants (client side) ─────────────────────────────

class ApplicantPiece {
  final String title;
  final String brief;
  final String role;
  final String madeOn;
  final String? liveLink;
  final List<WorkFile> files;
  const ApplicantPiece({
    required this.title,
    required this.brief,
    required this.role,
    required this.madeOn,
    required this.liveLink,
    required this.files,
  });
  factory ApplicantPiece.fromJson(Map<String, dynamic> j) => ApplicantPiece(
    title: (j['title'] as String?) ?? '',
    brief: (j['brief'] as String?) ?? '',
    role: (j['role'] as String?) ?? '',
    madeOn: (j['madeOn'] as String?) ?? '',
    liveLink: j['liveLink'] as String?,
    files: [for (final f in _maps(j['files'])) WorkFile.fromJson(f)],
  );
}

/// What a client sees for one applicant of a structured job: facts, chosen work and answers.
class ApplicantPanel {
  final TalentCard talent;
  final String? answer;
  final List<({String question, String answer})> screening;
  final List<ApplicantPiece> pieces;
  final bool invited;
  const ApplicantPanel({
    required this.talent,
    required this.answer,
    required this.screening,
    required this.pieces,
    required this.invited,
  });

  factory ApplicantPanel.fromJson(Map<String, dynamic> j) => ApplicantPanel(
    talent: TalentCard.fromJson(_map(j['talent'])),
    answer: j['answer'] as String?,
    screening: [
      for (final s in _maps(j['screening']))
        (
          question: s['question'] as String,
          answer: (s['answer'] as String?) ?? '',
        ),
    ],
    pieces: [for (final p in _maps(j['pieces'])) ApplicantPiece.fromJson(p)],
    invited: j['invited'] as bool? ?? false,
  );
}

class ApplicantCap {
  final int applicantCount;
  final int applicantCap;
  final bool paused;
  final String? reason;
  const ApplicantCap({
    required this.applicantCount,
    required this.applicantCap,
    required this.paused,
    required this.reason,
  });
  factory ApplicantCap.fromJson(Map<String, dynamic> j) => ApplicantCap(
    applicantCount: (j['applicantCount'] as num?)?.toInt() ?? 0,
    applicantCap: (j['applicantCap'] as num?)?.toInt() ?? 50,
    paused: j['paused'] as bool? ?? false,
    reason: j['reason'] as String?,
  );
}
