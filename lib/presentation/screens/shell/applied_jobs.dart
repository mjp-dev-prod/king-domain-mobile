import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../data/models/job.dart';
import '../../widgets/kit/kd_card.dart';

/// Jobs the viewer applied to that did not become theirs: still waiting, or
/// not picked. A selected application is a contract and lives under Awarded.
/// Waiting first, then newest first.
List<Job> appliedJobs(List<Job> jobs) {
  int rank(Job j) => j.applicationStatus == JobApplicationStatus.pending ? 0 : 1;
  final list = jobs
      .where((j) => j.applicationStatus == JobApplicationStatus.pending || j.applicationStatus == JobApplicationStatus.rejected)
      .toList();
  list.sort((a, b) {
    final r = rank(a) - rank(b);
    return r != 0 ? r : b.postedAt.compareTo(a.postedAt);
  });
  return list;
}

/// One line on where an application stands. Amber means waiting on someone;
/// "not picked" and "closed" are neutral, never red (nothing was missed).
({String text, KdTone tone}) appliedStatusLine(Job job) {
  if (job.closed) return (text: 'Closed by the client', tone: KdTone.plain);
  return switch (job.applicationStatus) {
    JobApplicationStatus.pending => (text: 'Waiting for ${job.clientName} to pick', tone: KdTone.warn),
    JobApplicationStatus.rejected => (text: 'Not picked', tone: KdTone.plain),
    _ => (text: '', tone: KdTone.plain),
  };
}

/// An application in the Applied list: title, client, budget and the status line.
class AppliedTile extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const AppliedTile({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = appliedStatusLine(job);
    final ink = status.tone == KdTone.plain ? AppColors.text2 : toneInk(status.tone);
    return KdCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(job.clientName, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis)),
              Text(
                formatNaira(job.budget),
                style: AppTextStyles.title.copyWith(color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(status.text, style: AppTextStyles.bodySmall.copyWith(color: ink, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
            ],
          ),
        ],
      ),
    );
  }
}
