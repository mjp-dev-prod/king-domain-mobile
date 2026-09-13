import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/job.dart';

class JobsNotifier extends Notifier<List<Job>> {
  @override
  List<Job> build() => mockJobs;

  void applyTo(String jobId) {
    state = [
      for (final job in state)
        if (job.id == jobId)
          job.copyWith(applicationStatus: JobApplicationStatus.pending)
        else
          job,
    ];
  }

  /// Simulates the founding team manually matching and funding a job — the
  /// wedge's actual mechanism (see docs/core/vision-vs-research-reconciliation.md
  /// §2). There's no client app yet, so "accepted" and "funded" happen
  /// together here rather than as separate real events.
  void simulateAcceptAndFund(String jobId) {
    state = [
      for (final job in state)
        if (job.id == jobId)
          job.copyWith(
            applicationStatus: JobApplicationStatus.accepted,
            contractStatus: ContractStatus.funded,
          )
        else
          job,
    ];
  }

  void startWork(String jobId) {
    state = [
      for (final job in state)
        if (job.id == jobId)
          job.copyWith(contractStatus: ContractStatus.inProgress)
        else
          job,
    ];
  }

  void submitDeliverable(String jobId, String note) {
    state = [
      for (final job in state)
        if (job.id == jobId)
          job.copyWith(
            contractStatus: ContractStatus.submitted,
            deliverableNote: note,
          )
        else
          job,
    ];
  }

  /// No client app exists yet — this simulates the client approving delivery
  /// so the release step is visible end-to-end in the talent app.
  void simulateClientApproval(String jobId) {
    state = [
      for (final job in state)
        if (job.id == jobId)
          job.copyWith(contractStatus: ContractStatus.approved)
        else
          job,
    ];
  }
}

final jobsProvider = NotifierProvider<JobsNotifier, List<Job>>(JobsNotifier.new);
