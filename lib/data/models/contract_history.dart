/// Mirrors GET /jobs/:id/contract/history (backend jobsRoutes.js): every
/// delivery version, extension request and change round on a contract,
/// oldest first. Visible to the job's client and its awarded talent only.
class ContractHistory {
  final List<DeliveryVersion> deliveries;
  final List<ExtensionRequest> extensions;
  final List<ChangeRound> changeRounds;

  const ContractHistory({this.deliveries = const [], this.extensions = const [], this.changeRounds = const []});

  factory ContractHistory.fromJson(Map<String, dynamic> json) => ContractHistory(
    deliveries: _list(json['deliveries'], DeliveryVersion.fromJson),
    extensions: _list(json['extensions'], ExtensionRequest.fromJson),
    changeRounds: _list(json['changeRequests'], ChangeRound.fromJson),
  );

  /// The extension request still waiting for the client's answer, if any.
  ExtensionRequest? get pendingExtension {
    for (final e in extensions) {
      if (e.status == ExtensionStatus.pending) return e;
    }
    return null;
  }

  ExtensionRequest? get latestExtension => extensions.isEmpty ? null : extensions.last;
  ChangeRound? get latestChangeRound => changeRounds.isEmpty ? null : changeRounds.last;
  DeliveryVersion? get latestDelivery => deliveries.isEmpty ? null : deliveries.last;
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
    (raw as List? ?? const []).map((e) => parse(e as Map<String, dynamic>)).toList();

DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');

class DeliveryVersion {
  final int version;
  final String? note;
  final String? url;
  /// Short-lived signed link to the uploaded file; re-fetch history for a fresh one.
  final String? fileUrl;
  final DateTime submittedAt;

  const DeliveryVersion({required this.version, this.note, this.url, this.fileUrl, required this.submittedAt});

  factory DeliveryVersion.fromJson(Map<String, dynamic> json) => DeliveryVersion(
    version: json['version'] as int,
    note: json['note'] as String?,
    url: json['url'] as String?,
    fileUrl: json['fileUrl'] as String?,
    submittedAt: _date(json['submittedAt']) ?? DateTime.now(),
  );
}

/// Backend ExtensionStatus. [withdrawn]: the talent delivered while it was open.
enum ExtensionStatus { pending, granted, declined, autoGranted, withdrawn }

class ExtensionRequest {
  final String id;
  final int requestedDays;
  final String reason;
  final ExtensionStatus status;
  final DateTime requestedAt;
  final DateTime answerDueAt;
  final DateTime? resolvedAt;

  const ExtensionRequest({
    required this.id,
    required this.requestedDays,
    required this.reason,
    required this.status,
    required this.requestedAt,
    required this.answerDueAt,
    this.resolvedAt,
  });

  factory ExtensionRequest.fromJson(Map<String, dynamic> json) => ExtensionRequest(
    id: json['id'] as String,
    requestedDays: json['requestedDays'] as int,
    reason: json['reason'] as String? ?? '',
    status: ExtensionStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => ExtensionStatus.pending),
    requestedAt: _date(json['requestedAt']) ?? DateTime.now(),
    answerDueAt: _date(json['answerDueAt']) ?? DateTime.now(),
    resolvedAt: _date(json['resolvedAt']),
  );
}

class ChangeRound {
  final int round;
  final String reason;
  final DateTime requestedAt;
  final DateTime resubmitDueAt;
  final DateTime? resubmittedAt;

  const ChangeRound({required this.round, required this.reason, required this.requestedAt, required this.resubmitDueAt, this.resubmittedAt});

  factory ChangeRound.fromJson(Map<String, dynamic> json) => ChangeRound(
    round: json['round'] as int,
    reason: json['reason'] as String? ?? '',
    requestedAt: _date(json['requestedAt']) ?? DateTime.now(),
    resubmitDueAt: _date(json['resubmitDueAt']) ?? DateTime.now(),
    resubmittedAt: _date(json['resubmittedAt']),
  );
}
