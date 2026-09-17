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
  final String? deliverableNote;
  final String? deliverableUrl;
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
    this.deliverableNote,
    this.deliverableUrl,
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
      deliverableNote: contract?['deliverableNote'] as String?,
      deliverableUrl: contract?['deliverableUrl'] as String?,
      applicationStatus: _applicationStatusFromString(json['myApplicationStatus'] as String?),
    );
  }

  Job copyWith({
    JobApplicationStatus? applicationStatus,
    ContractStatus? contractStatus,
    String? deliverableNote,
    String? deliverableUrl,
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
      deliverableNote: deliverableNote ?? this.deliverableNote,
      deliverableUrl: deliverableUrl ?? this.deliverableUrl,
      applicationStatus: applicationStatus ?? this.applicationStatus,
    );
  }
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
/// visible funded → in-progress → submitted → approved lifecycle — now real
/// server-side state (backend Contract model), not local app state. Nothing
/// here is wired to a real payment/escrow provider yet (Sprint 5 in
/// docs/research/BACKEND_SPRINT_PLAN.md) — "funded" means the state
/// transitioned correctly, not that money actually moved.
enum ContractStatus { funded, inProgress, submitted, approved }

ContractStatus? _contractStatusFromString(String? value) {
  switch (value) {
    case 'funded':
      return ContractStatus.funded;
    case 'inProgress':
      return ContractStatus.inProgress;
    case 'submitted':
      return ContractStatus.submitted;
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

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.talentId,
    required this.talentName,
    required this.status,
    required this.createdAt,
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
    );
  }
}
