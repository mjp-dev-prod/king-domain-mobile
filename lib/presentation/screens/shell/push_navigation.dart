import 'package:flutter/material.dart';
import '../../../data/models/job.dart';
import '../client/applicants_screen.dart';
import '../client/client_contract_screen.dart';
import '../contracts/contract_detail_screen.dart';
import '../jobs/job_detail_screen.dart';
import '../payments/fund_contract_screen.dart';

/// Where a tapped push should land: the same screen the tabs open for that job. Null when the job is not
/// one this person can see (gone, or not theirs): the app then just stays where it is.
Widget? screenForPush({required String? role, required Job? job}) {
  if (job == null) return null;
  if (role == 'client') {
    return switch (job.contractStatus) {
      null => ApplicantsScreen(job: job),
      ContractStatus.awaitingPayment => FundContractScreen(jobId: job.id),
      _ => ClientContractScreen(jobId: job.id),
    };
  }
  // A talent: the contract when they were picked for it, otherwise the job itself.
  final theirContract = job.contractStatus != null && job.applicationStatus == JobApplicationStatus.accepted;
  return theirContract ? ContractDetailScreen(jobId: job.id) : JobDetailScreen(jobId: job.id);
}
