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
}

final jobsProvider = NotifierProvider<JobsNotifier, List<Job>>(JobsNotifier.new);
