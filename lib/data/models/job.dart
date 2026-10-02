/// Mirrors king-domain-backend's /jobs API shapes (src/user/jobsRoutes.js's
/// serializeJob/serializeApplication/serializeContract). Application status
/// now lives on a separate Application record server-side (a Job can have
/// many applicants), not embedded on Job like the old local mock — see
/// JobApplicationStatus below for how that's represented here instead.
class Job {
  final String id;
  final String title;
  final String category;
  final String description;
  final double budget;
  final String clientId;
  final String clientName;
  /// No reputation/rating field exists on the backend yet — client rating
  /// and completed-job count are planned additions, not real data right
  /// now. Defaults to 0/no-rating rather than a fabricated number; update
  /// this comment and the fromJson mapping once the backend field exists.
  final double clientRating;
  final int clientCompletedJobs;
  final DateTime postedAt;
  final String? awardedApplicationId;
  final int applicationCount;
  final ContractStatus? contractStatus;
  /// 10% of budget, frozen onto the contract at award time — see backend
  /// paystack.js's PLATFORM_FEE_RATE. Paid by the client on top of the
  /// budget; the talent always receives the full budget.
  final double? platformFeeAmount;
  /// Paystack reported the last checkout attempt as failed.
  final bool paymentFailed;
  /// The client must pay by this time or the award cancels itself (24h after
  /// award). Only meaningful while the contract is awaitingPayment.
  final DateTime? payByAt;
  /// When payment is released automatically if the client does nothing. The
  /// backend only sends it while auto-release is actually switched on, so a
  /// non-null value is always a real promise.
  final DateTime? reviewDueAt;
  /// Days the talent has to deliver, counted from funding (stage 2). Null on
  /// jobs posted before delivery dates existed: no deadline features.
  final int? deliveryDays;
  final DateTime? fundedAt;
  /// fundedAt + deliveryDays, moved later by granted extensions.
  final DateTime? deliverByAt;
  /// Extension requests made on this contract (a declined one counts; max 2).
  final int extensionsUsed;
  /// Change rounds the client has opened (max 2; after that, an admin).
  final int changeRounds;
  /// While changesRequested: the talent resubmits by this or it goes to an admin.
  final DateTime? changeDueAt;
  /// The delivery date passed by 3 days with nothing delivered (flag only;
  /// cancel-for-refund isn't built until stage 3).
  final bool overdue;
  final String? deliverableNote;
  final String? deliverableUrl;
  /// A short-lived signed URL to the uploaded deliverable file, if one was
  /// attached at submit — resolved server-side from Contract.
  /// deliverableFilePath (private Supabase Storage), same pattern as
  /// ProofItem.fileUrl. Re-fetch the job/contract to get a fresh link once
  /// this one expires; never cache it long-term.
  final String? deliverableFileUrl;
  /// Set from a separate /jobs/:id/applications lookup (the current
  /// user's own application on this job, if any) — the backend doesn't
  /// embed this on the job payload itself, since a job has many
  /// applicants and "my status" only makes sense from one talent's view.
  final JobApplicationStatus applicationStatus;

  const Job({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.budget,
    required this.clientId,
    required this.clientName,
    this.clientRating = 0,
    this.clientCompletedJobs = 0,
    required this.postedAt,
    this.awardedApplicationId,
    this.applicationCount = 0,
    this.contractStatus,
    this.platformFeeAmount,
    this.paymentFailed = false,
    this.payByAt,
    this.reviewDueAt,
    this.deliveryDays,
    this.fundedAt,
    this.deliverByAt,
    this.extensionsUsed = 0,
    this.changeRounds = 0,
    this.changeDueAt,
    this.overdue = false,
    this.deliverableNote,
    this.deliverableUrl,
    this.deliverableFileUrl,
    this.applicationStatus = JobApplicationStatus.notApplied,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>?;
    final contract = json['contract'] as Map<String, dynamic>?;
    return Job(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      budget: double.tryParse(json['budget']?.toString() ?? '') ?? 0,
      clientId: client?['id'] as String? ?? '',
      clientName: client?['fullName'] as String? ?? 'Client',
      postedAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      awardedApplicationId: json['awardedApplicationId'] as String?,
      applicationCount: json['applicationCount'] as int? ?? 0,
      contractStatus: contract != null ? _contractStatusFromString(contract['status'] as String?) : null,
      platformFeeAmount: double.tryParse(contract?['platformFeeAmount']?.toString() ?? ''),
      paymentFailed: contract?['paymentFailed'] as bool? ?? false,
      payByAt: DateTime.tryParse(contract?['payByAt'] as String? ?? ''),
      reviewDueAt: DateTime.tryParse(contract?['reviewDueAt'] as String? ?? ''),
      deliveryDays: json['deliveryDays'] as int?,
      fundedAt: DateTime.tryParse(contract?['fundedAt'] as String? ?? ''),
      deliverByAt: DateTime.tryParse(contract?['deliverByAt'] as String? ?? ''),
      extensionsUsed: contract?['extensionsUsed'] as int? ?? 0,
      changeRounds: contract?['changeRounds'] as int? ?? 0,
      changeDueAt: DateTime.tryParse(contract?['changeDueAt'] as String? ?? ''),
      overdue: contract?['overdue'] as bool? ?? false,
      deliverableNote: contract?['deliverableNote'] as String?,
      deliverableUrl: contract?['deliverableUrl'] as String?,
      deliverableFileUrl: contract?['deliverableFileUrl'] as String?,
      applicationStatus: _applicationStatusFromString(json['myApplicationStatus'] as String?),
    );
  }

  Job copyWith({
    JobApplicationStatus? applicationStatus,
    ContractStatus? contractStatus,
    String? deliverableNote,
    String? deliverableUrl,
    String? deliverableFileUrl,
    String? awardedApplicationId,
    int? applicationCount,
  }) {
    return Job(
      id: id,
      title: title,
      category: category,
      description: description,
      budget: budget,
      clientId: clientId,
      clientName: clientName,
      clientRating: clientRating,
      clientCompletedJobs: clientCompletedJobs,
      postedAt: postedAt,
      awardedApplicationId: awardedApplicationId ?? this.awardedApplicationId,
      applicationCount: applicationCount ?? this.applicationCount,
      contractStatus: contractStatus ?? this.contractStatus,
      platformFeeAmount: platformFeeAmount,
      paymentFailed: paymentFailed,
      payByAt: payByAt,
      reviewDueAt: reviewDueAt,
      deliveryDays: deliveryDays,
      fundedAt: fundedAt,
      deliverByAt: deliverByAt,
      extensionsUsed: extensionsUsed,
      changeRounds: changeRounds,
      changeDueAt: changeDueAt,
      overdue: overdue,
      deliverableNote: deliverableNote ?? this.deliverableNote,
      deliverableUrl: deliverableUrl ?? this.deliverableUrl,
      deliverableFileUrl: deliverableFileUrl ?? this.deliverableFileUrl,
      applicationStatus: applicationStatus ?? this.applicationStatus,
    );
  }

  /// What the client pays at checkout: budget + platform fee.
  double get clientTotal => budget + (platformFeeAmount ?? 0);

  /// Agreed limits (backend contractCore RULES), mirrored so the app can say
  /// what's left before the server has to refuse.
  static const maxExtensionRequests = 2;
  static const maxChangeRounds = 2;

  int get extensionRequestsLeft => (maxExtensionRequests - extensionsUsed).clamp(0, maxExtensionRequests);
  int get changeRoundsLeft => (maxChangeRounds - changeRounds).clamp(0, maxChangeRounds);
}

enum JobApplicationStatus { notApplied, pending, accepted, rejected }

/// Maps the backend's ApplicationStatus enum ('pending' | 'selected' |
/// 'notSelected', from Job.myApplicationStatus — see backend
/// jobsRoutes.js's serializeJob) onto the existing Flutter enum names.
/// 'selected' -> accepted, 'notSelected' -> rejected: same states, names
/// kept from before the backend existed rather than renaming every call
/// site that already reads well (job.applicationStatus == accepted).
JobApplicationStatus _applicationStatusFromString(String? value) {
  switch (value) {
    case 'pending':
      return JobApplicationStatus.pending;
    case 'selected':
      return JobApplicationStatus.accepted;
    case 'notSelected':
      return JobApplicationStatus.rejected;
    default:
      return JobApplicationStatus.notApplied;
  }
}

/// The wedge's actual product bet (see docs/core/vision-vs-research-reconciliation.md
/// §2): once a client awards a talent, the job's money moves through a plain,
/// visible lifecycle. Backed by real Paystack money movement: awaitingPayment
/// until the client pays at checkout, funded once Paystack confirms it, and
/// approval transfers the budget to the talent's bank account.
///
/// Stage 2 adds two: changesRequested (the client sent delivered work back;
/// the talent owes a resubmit by changeDueAt) and disputed (parked for a King
/// Domain admin after round 2, or a missed resubmit clock; stage 3 resolves it).
enum ContractStatus { awaitingPayment, funded, inProgress, submitted, changesRequested, disputed, approved }

ContractStatus? _contractStatusFromString(String? value) {
  switch (value) {
    case 'awaitingPayment':
      return ContractStatus.awaitingPayment;
    case 'funded':
      return ContractStatus.funded;
    case 'inProgress':
      return ContractStatus.inProgress;
    case 'submitted':
      return ContractStatus.submitted;
    case 'changesRequested':
      return ContractStatus.changesRequested;
    case 'disputed':
      return ContractStatus.disputed;
    case 'approved':
      return ContractStatus.approved;
    default:
      return null;
  }
}

/// One applicant on a job, from GET /jobs/:id/applications (client-only) —
/// mirrors backend serializeApplication.
class JobApplication {
  final String id;
  final String jobId;
  final String talentId;
  final String talentName;
  final String status; // 'pending' | 'selected' | 'notSelected'
  final DateTime createdAt;
  /// Real facts the client weighs (no score, no rank): see ApplicantSignals.
  final ApplicantSignals signals;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.talentId,
    required this.talentName,
    required this.status,
    required this.createdAt,
    this.signals = const ApplicantSignals(),
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    final talent = json['talent'] as Map<String, dynamic>?;
    return JobApplication(
      id: json['id'] as String,
      jobId: json['jobId'] as String,
      talentId: talent?['id'] as String? ?? '',
      talentName: talent?['fullName'] as String? ?? 'Talent',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      signals: ApplicantSignals.fromJson(json['signals'] as Map<String, dynamic>?),
    );
  }
}

/// docs/core/correction-talent-discovery-screen.md: verified status in the
/// job's category, their verified work samples there, and a plain count of
/// completed jobs. A newcomer with 0 jobs is shown plainly, not ranked down.
class ApplicantSignals {
  final String? headline;
  final bool verifiedInCategory;
  final List<({String id, String title, String? fileUrl})> proof;
  final int jobsCompleted;

  const ApplicantSignals({this.headline, this.verifiedInCategory = false, this.proof = const [], this.jobsCompleted = 0});

  factory ApplicantSignals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ApplicantSignals();
    return ApplicantSignals(
      headline: json['headline'] as String?,
      verifiedInCategory: json['verifiedInCategory'] as bool? ?? false,
      proof: (json['proof'] as List? ?? const [])
          .map((p) => (id: p['id'] as String, title: p['title'] as String? ?? '', fileUrl: p['fileUrl'] as String?))
          .toList(),
      jobsCompleted: json['jobsCompleted'] as int? ?? 0,
    );
  }
}
