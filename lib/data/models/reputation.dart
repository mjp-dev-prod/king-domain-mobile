// Mirrors king-domain-backend's src/reputation.js and src/user/reviewRoutes.js (PRD §4.8; D29 to D32): reviews as
// specific questions rather than stars, facts the system measured, plain counts, Proven per skill, portable credentials.
// There is no average, no score and no rank anywhere in these classes, on purpose.

DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
List<Map<String, dynamic>> _maps(Object? v) => [for (final e in (v as List? ?? const [])) e as Map<String, dynamic>];

class ReviewQuestion {
  final String key;
  final String label;
  /// triple (yes / partly / no) or bool (yes / no).
  final String kind;
  const ReviewQuestion({required this.key, required this.label, required this.kind});

  factory ReviewQuestion.fromJson(Map<String, dynamic> j) => ReviewQuestion(key: j['key'] as String, label: j['label'] as String, kind: j['kind'] as String);
}

/// Measured from timestamps, not opinions.
class JobFacts {
  final int? startProofHours;
  final bool? deliveredOnTime;
  final int daysLate;
  final int changeRounds;
  final int extensionsUsed;
  final String outcome;
  const JobFacts({this.startProofHours, this.deliveredOnTime, this.daysLate = 0, this.changeRounds = 0, this.extensionsUsed = 0, this.outcome = 'completed'});

  factory JobFacts.fromJson(Map<String, dynamic> j) => JobFacts(
    startProofHours: (j['startProofHours'] as num?)?.toInt(),
    deliveredOnTime: j['deliveredOnTime'] as bool?,
    daysLate: _int(j['daysLate']),
    changeRounds: _int(j['changeRounds']),
    extensionsUsed: _int(j['extensionsUsed']),
    outcome: j['outcome'] as String? ?? 'completed',
  );

  /// The facts as short lines: "Delivered on time", "2 change rounds".
  List<String> get lines => [
    if (deliveredOnTime == true) 'Delivered on time' else if (deliveredOnTime == false) 'Delivered $daysLate day${daysLate == 1 ? '' : 's'} late',
    if (startProofHours != null) 'Start proof sent ${startProofHours == 0 ? 'right away' : 'after $startProofHours h'}',
    '$changeRounds change round${changeRounds == 1 ? '' : 's'}',
    if (extensionsUsed > 0) '$extensionsUsed extension${extensionsUsed == 1 ? '' : 's'} used',
    if (outcome != 'completed') 'Settled by agreement or ruling',
  ];
}

class ReviewBody {
  final String id;
  final Map<String, dynamic> answers;
  final String comment;
  final String? reply;
  final DateTime? repliedAt;
  final DateTime? at;
  final bool removed;
  /// Only on your own review: the private answer nobody else sees.
  final bool? privateAgain;
  const ReviewBody({required this.id, required this.answers, required this.comment, this.reply, this.repliedAt, this.at, this.removed = false, this.privateAgain});

  factory ReviewBody.fromJson(Map<String, dynamic> j) => ReviewBody(
    id: j['id'] as String,
    answers: (j['answers'] as Map?)?.cast<String, dynamic>() ?? const {},
    comment: j['comment'] as String? ?? '',
    reply: j['reply'] as String?,
    repliedAt: _date(j['repliedAt']),
    at: _date(j['at']),
    removed: j['removed'] as bool? ?? false,
    privateAgain: j['privateAgain'] as bool?,
  );
}

/// One person's review screen for one job. [state]: not_yet, can_review, waiting, revealed or window_closed.
class ReviewState {
  final String role;
  final String direction;
  final List<ReviewQuestion> questions;
  final String privateQuestion;
  final JobFacts? facts;
  final String? otherName;
  final String state;
  final String? message;
  final DateTime? windowEndsAt;
  final int daysLeft;
  final ReviewBody? mine;
  final ReviewBody? theirs;
  final bool theirsExists;
  final bool canEdit;
  final bool canReply;

  const ReviewState({
    required this.role,
    required this.direction,
    required this.questions,
    required this.privateQuestion,
    required this.facts,
    required this.otherName,
    required this.state,
    required this.message,
    required this.windowEndsAt,
    required this.daysLeft,
    required this.mine,
    required this.theirs,
    required this.theirsExists,
    required this.canEdit,
    required this.canReply,
  });

  bool get isClient => role == 'client';

  factory ReviewState.fromJson(Map<String, dynamic> json) {
    final j = json['review'] as Map<String, dynamic>;
    return ReviewState(
      role: j['role'] as String,
      direction: j['direction'] as String,
      questions: [for (final q in _maps(j['questions'])) ReviewQuestion.fromJson(q)],
      privateQuestion: j['privateQuestion'] as String? ?? '',
      facts: j['facts'] == null ? null : JobFacts.fromJson(j['facts'] as Map<String, dynamic>),
      otherName: j['otherName'] as String?,
      state: j['state'] as String,
      message: j['message'] as String?,
      windowEndsAt: _date(j['windowEndsAt']),
      daysLeft: _int(j['daysLeft']),
      mine: j['mine'] == null ? null : ReviewBody.fromJson(j['mine'] as Map<String, dynamic>),
      theirs: j['theirs'] == null ? null : ReviewBody.fromJson(j['theirs'] as Map<String, dynamic>),
      theirsExists: j['theirsExists'] as bool? ?? false,
      canEdit: j['canEdit'] as bool? ?? false,
      canReply: j['canReply'] as bool? ?? false,
    );
  }
}

/// A visible review on a profile, with the facts of that job.
class PublicReview {
  final String id;
  final String direction;
  final String jobTitle;
  final String skillLabel;
  final DateTime at;
  final Map<String, dynamic> answers;
  final String comment;
  final String? reply;
  final JobFacts? facts;
  /// Older than 12 months: the last year leads, the rest is a tap away.
  final bool older;
  const PublicReview({required this.id, required this.direction, required this.jobTitle, required this.skillLabel, required this.at, required this.answers, required this.comment, required this.reply, required this.facts, required this.older});

  factory PublicReview.fromJson(Map<String, dynamic> j) => PublicReview(
    id: j['id'] as String,
    direction: j['direction'] as String? ?? '',
    jobTitle: j['jobTitle'] as String? ?? '',
    skillLabel: j['skillLabel'] as String? ?? '',
    at: _date(j['at']) ?? DateTime.now(),
    answers: (j['answers'] as Map?)?.cast<String, dynamic>() ?? const {},
    comment: j['comment'] as String? ?? '',
    reply: j['reply'] as String?,
    facts: j['facts'] == null ? null : JobFacts.fromJson(j['facts'] as Map<String, dynamic>),
    older: j['older'] as bool? ?? false,
  );
}

class SkillTally {
  final String? skillKey;
  final String skillLabel;
  final int jobs;
  final int onTime;
  final int reviewed;
  final int recommend;
  const SkillTally({required this.skillKey, required this.skillLabel, required this.jobs, required this.onTime, required this.reviewed, required this.recommend});

  factory SkillTally.fromJson(Map<String, dynamic> j) => SkillTally(
    skillKey: j['skillKey'] as String?,
    skillLabel: j['skillLabel'] as String? ?? '',
    jobs: _int(j['jobs']),
    onTime: _int(j['onTime']),
    reviewed: _int(j['reviewed']),
    recommend: _int(j['recommend']),
  );

  /// "6 jobs in short-form video · 6 on time · 5 of 6 clients would recommend".
  String get line => '$jobs job${jobs == 1 ? '' : 's'} in $skillLabel · $onTime on time${reviewed == 0 ? '' : ' · $recommend of $reviewed client${reviewed == 1 ? '' : 's'} would recommend'}';
}

class ProvenInfo {
  final String skillKey;
  final String skillLabel;
  final bool proven;
  final int completed;
  final int needed;
  final int recommended;
  final List<String> unmet;
  const ProvenInfo({required this.skillKey, required this.skillLabel, required this.proven, required this.completed, required this.needed, required this.recommended, required this.unmet});

  factory ProvenInfo.fromJson(Map<String, dynamic> j) => ProvenInfo(
    skillKey: j['skillKey'] as String,
    skillLabel: j['skillLabel'] as String? ?? '',
    proven: j['proven'] as bool? ?? false,
    completed: _int(j['completed']),
    needed: _int(j['needed']),
    recommended: _int(j['recommended']),
    unmet: [for (final u in (j['unmet'] as List? ?? const [])) u as String],
  );
}

class TalentReputation {
  final int completedJobs;
  final int lostDisputes;
  final List<SkillTally> skills;
  final List<PublicReview> reviews;
  final int reviewCount;
  final List<ProvenInfo> proven;
  const TalentReputation({this.completedJobs = 0, this.lostDisputes = 0, this.skills = const [], this.reviews = const [], this.reviewCount = 0, this.proven = const []});

  bool get isEmpty => completedJobs == 0 && reviews.isEmpty;

  factory TalentReputation.fromJson(Map<String, dynamic> j) => TalentReputation(
    completedJobs: _int(j['completedJobs']),
    lostDisputes: _int(j['lostDisputes']),
    skills: [for (final s in _maps(j['skills'])) SkillTally.fromJson(s)],
    reviews: [for (final r in _maps(j['reviews'])) PublicReview.fromJson(r)],
    reviewCount: _int(j['reviewCount']),
    proven: [for (final p in _maps(j['proven'])) ProvenInfo.fromJson(p)],
  );
}

class ClientTally {
  final int reviewed;
  final int briefClear;
  final int feedbackClear;
  final int paidFairly;
  final int recommend;
  const ClientTally({this.reviewed = 0, this.briefClear = 0, this.feedbackClear = 0, this.paidFairly = 0, this.recommend = 0});

  factory ClientTally.fromJson(Map<String, dynamic> j) => ClientTally(
    reviewed: _int(j['reviewed']),
    briefClear: _int(j['briefClear']),
    feedbackClear: _int(j['feedbackClear']),
    paidFairly: _int(j['paidFairly']),
    recommend: _int(j['recommend']),
  );
}

/// What talents said about a client, as plain counts, plus how the client actually behaves (D19).
class ClientReputation {
  final ClientTally tally;
  final List<PublicReview> reviews;
  final int reviewCount;
  final int? reviewHoursMedian;
  final double? changeRoundsPerJob;
  final int disputesLost;
  final int jobsDone;
  const ClientReputation({this.tally = const ClientTally(), this.reviews = const [], this.reviewCount = 0, this.reviewHoursMedian, this.changeRoundsPerJob, this.disputesLost = 0, this.jobsDone = 0});

  factory ClientReputation.fromJson(Map<String, dynamic> j) => ClientReputation(
    tally: j['tally'] == null ? const ClientTally() : ClientTally.fromJson(j['tally'] as Map<String, dynamic>),
    reviews: [for (final r in _maps(j['reviews'])) PublicReview.fromJson(r)],
    reviewCount: _int(j['reviewCount']),
    reviewHoursMedian: (j['reviewHoursMedian'] as num?)?.toInt(),
    changeRoundsPerJob: (j['changeRoundsPerJob'] as num?)?.toDouble(),
    disputesLost: _int(j['disputesLost']),
    jobsDone: _int(j['jobsDone']),
  );
}

/// The signed-in person's own reputation: a talent's, or a client's.
class MyReputation {
  final String role;
  final TalentReputation? talent;
  final ClientReputation? client;
  const MyReputation({required this.role, this.talent, this.client});

  factory MyReputation.fromJson(Map<String, dynamic> j) => MyReputation(
    role: j['role'] as String,
    talent: j['talent'] == null ? null : TalentReputation.fromJson(j['talent'] as Map<String, dynamic>),
    client: j['client'] == null ? null : ClientReputation.fromJson(j['client'] as Map<String, dynamic>),
  );
}

class CredentialItem {
  final String id;
  final String kind;
  final String title;
  final String description;
  final DateTime issuedAt;
  final bool signed;
  final bool revoked;
  final String? revokedReason;
  final String? url;
  const CredentialItem({required this.id, required this.kind, required this.title, required this.description, required this.issuedAt, required this.signed, required this.revoked, this.revokedReason, this.url});

  factory CredentialItem.fromJson(Map<String, dynamic> j) => CredentialItem(
    id: j['id'] as String,
    kind: j['kind'] as String,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    issuedAt: _date(j['issuedAt']) ?? DateTime.now(),
    signed: j['signed'] as bool? ?? false,
    revoked: j['revoked'] as bool? ?? false,
    revokedReason: j['revokedReason'] as String?,
    url: j['url'] as String?,
  );
}

class CredentialList {
  final List<CredentialItem> credentials;
  /// The team has set the signing key: credentials can be shared. Without it they are recorded but not shareable yet.
  final bool signingAvailable;
  const CredentialList({required this.credentials, required this.signingAvailable});

  factory CredentialList.fromJson(Map<String, dynamic> j) => CredentialList(credentials: [for (final c in _maps(j['credentials'])) CredentialItem.fromJson(c)], signingAvailable: j['signingAvailable'] as bool? ?? false);
}

class ReviewReason {
  final String code;
  final String label;
  const ReviewReason(this.code, this.label);
}

/// Why a review may be reported. Disagreeing with an honest review is not one: that is what the reply is for.
const reviewReportReasons = [
  ReviewReason('abuse', 'Threats or abuse'),
  ReviewReason('personal_info', 'Personal information'),
  ReviewReason('unrelated', 'Not about the work'),
  ReviewReason('leverage', 'Used as leverage'),
];
