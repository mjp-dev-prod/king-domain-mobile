// Mirrors king-domain-backend's src/user/disputeRoutes.js: "Something's wrong" (PRD §3.3). The server decides what is
// allowed and what the rule is; these classes only carry it.

DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');

class DisputeProblem {
  final String code;
  final String label;
  final String rule;
  const DisputeProblem({required this.code, required this.label, required this.rule});

  factory DisputeProblem.fromJson(Map<String, dynamic> j) => DisputeProblem(code: j['code'] as String, label: j['label'] as String, rule: j['rule'] as String? ?? '');
}

/// A fixed way out. [needs] is "days" (more time), "talentPercent" (a split) or null.
class DisputeWay {
  final String kind;
  final String label;
  final String? needs;
  const DisputeWay({required this.kind, required this.label, this.needs});

  factory DisputeWay.fromJson(Map<String, dynamic> j) => DisputeWay(kind: j['kind'] as String, label: j['label'] as String, needs: j['needs'] as String?);
}

class DisputeOffer {
  final String id;
  final String kind;
  final String label;
  final String description;
  final String note;
  /// pending, accepted, declined or expired.
  final String status;
  final bool byMe;
  final DateTime answerDueAt;
  final DateTime createdAt;
  const DisputeOffer({required this.id, required this.kind, required this.label, required this.description, required this.note, required this.status, required this.byMe, required this.answerDueAt, required this.createdAt});

  bool get pending => status == 'pending';

  factory DisputeOffer.fromJson(Map<String, dynamic> j) => DisputeOffer(
    id: j['id'] as String,
    kind: j['kind'] as String,
    label: j['label'] as String? ?? j['kind'] as String,
    description: j['description'] as String? ?? '',
    note: j['note'] as String? ?? '',
    status: j['status'] as String,
    byMe: j['byMe'] as bool? ?? false,
    answerDueAt: _date(j['answerDueAt']) ?? DateTime.now(),
    createdAt: _date(j['createdAt']) ?? DateTime.now(),
  );
}

/// The team's decision, with the reasons both people can read.
class DisputeRulingView {
  final String outcome;
  final int talentPercent;
  final String reasons;
  final double talentAmount;
  final double clientRefund;
  final DateTime? decidedAt;
  const DisputeRulingView({required this.outcome, required this.talentPercent, required this.reasons, required this.talentAmount, required this.clientRefund, this.decidedAt});

  factory DisputeRulingView.fromJson(Map<String, dynamic> j) => DisputeRulingView(
    outcome: j['outcome'] as String,
    talentPercent: (j['talentPercent'] as num).toInt(),
    reasons: j['reasons'] as String? ?? '',
    talentAmount: (j['talentAmount'] as num?)?.toDouble() ?? 0,
    clientRefund: (j['clientRefund'] as num?)?.toDouble() ?? 0,
    decidedAt: _date(j['decidedAt']),
  );
}

class DisputeView {
  final String id;
  /// open (finding a way out), escalated (with the team), resolved.
  final String status;
  final String problem;
  final String problemLabel;
  final String? rule;
  final String note;
  final String filedByRole;
  final bool filedByMe;
  final DateTime openedAt;
  final DateTime? escalatedAt;
  final String? escalationReason;
  final DateTime? rulingDueAt;
  final DateTime? resolvedAt;
  /// {by: agreement | ruling, kind, talentPercent}
  final Map<String, dynamic>? resolution;
  final bool awaitingApproval;
  final DisputeRulingView? ruling;
  final List<DisputeOffer> offers;

  const DisputeView({
    required this.id,
    required this.status,
    required this.problem,
    required this.problemLabel,
    required this.rule,
    required this.note,
    required this.filedByRole,
    required this.filedByMe,
    required this.openedAt,
    required this.escalatedAt,
    required this.escalationReason,
    required this.rulingDueAt,
    required this.resolvedAt,
    required this.resolution,
    required this.awaitingApproval,
    required this.ruling,
    required this.offers,
  });

  bool get isOpen => status == 'open';
  bool get isEscalated => status == 'escalated';
  bool get isResolved => status == 'resolved';
  bool get live => isOpen || isEscalated;
  DisputeOffer? get pendingOffer => offers.where((o) => o.pending).firstOrNull;

  factory DisputeView.fromJson(Map<String, dynamic> j) => DisputeView(
    id: j['id'] as String,
    status: j['status'] as String,
    problem: j['problem'] as String,
    problemLabel: j['problemLabel'] as String? ?? j['problem'] as String,
    rule: j['rule'] as String?,
    note: j['note'] as String? ?? '',
    filedByRole: j['filedByRole'] as String? ?? '',
    filedByMe: j['filedByMe'] as bool? ?? false,
    openedAt: _date(j['openedAt']) ?? DateTime.now(),
    escalatedAt: _date(j['escalatedAt']),
    escalationReason: j['escalationReason'] as String?,
    rulingDueAt: _date(j['rulingDueAt']),
    resolvedAt: _date(j['resolvedAt']),
    resolution: (j['resolution'] as Map?)?.cast<String, dynamic>(),
    awaitingApproval: j['awaitingApproval'] as bool? ?? false,
    ruling: j['ruling'] == null ? null : DisputeRulingView.fromJson(j['ruling'] as Map<String, dynamic>),
    offers: [for (final p in (j['proposals'] as List? ?? const [])) DisputeOffer.fromJson(p as Map<String, dynamic>)],
  );
}

/// Everything the "Something's wrong" screen needs for one job.
class DisputeState {
  final String role;
  final DisputeView? dispute;
  final List<DisputeProblem> problems;
  final List<DisputeWay> ways;
  final bool canFile;
  final double held;
  final String? heldNote;
  final bool canCancelForRefund;
  final DateTime? cancelFrom;
  final int maxMoreDays;
  final bool hasAddress;

  const DisputeState({
    required this.role,
    required this.dispute,
    required this.problems,
    required this.ways,
    required this.canFile,
    required this.held,
    required this.heldNote,
    required this.canCancelForRefund,
    required this.cancelFrom,
    required this.maxMoreDays,
    required this.hasAddress,
  });

  bool get isClient => role == 'client';

  factory DisputeState.fromJson(Map<String, dynamic> j) => DisputeState(
    role: j['role'] as String,
    dispute: j['dispute'] == null ? null : DisputeView.fromJson(j['dispute'] as Map<String, dynamic>),
    problems: [for (final p in (j['problems'] as List? ?? const [])) DisputeProblem.fromJson(p as Map<String, dynamic>)],
    ways: [for (final w in (j['ways'] as List? ?? const [])) DisputeWay.fromJson(w as Map<String, dynamic>)],
    canFile: j['canFile'] as bool? ?? false,
    held: (j['held'] as num?)?.toDouble() ?? 0,
    heldNote: j['heldNote'] as String?,
    canCancelForRefund: j['canCancelForRefund'] as bool? ?? false,
    cancelFrom: _date(j['cancelFrom']),
    maxMoreDays: (j['maxMoreDays'] as num?)?.toInt() ?? 7,
    hasAddress: j['hasAddress'] as bool? ?? false,
  );
}

class Address {
  final String line;
  final String city;
  final String state;
  const Address({this.line = '', this.city = '', this.state = ''});

  bool get complete => line.trim().length >= 5 && city.trim().length >= 2 && state.trim().length >= 2;

  factory Address.fromJson(Map<String, dynamic> j) => Address(line: j['line'] as String? ?? '', city: j['city'] as String? ?? '', state: j['state'] as String? ?? '');
}

class AddressInfo {
  final Address address;
  /// Why it is asked for, in the words the person is shown (NDPA: the purpose is stated).
  final String purpose;
  const AddressInfo({required this.address, required this.purpose});

  factory AddressInfo.fromJson(Map<String, dynamic> j) => AddressInfo(address: Address.fromJson(j['address'] as Map<String, dynamic>), purpose: j['purpose'] as String? ?? '');
}
