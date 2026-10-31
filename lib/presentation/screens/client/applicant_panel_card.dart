import 'package:flutter/material.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/job.dart';
import '../../widgets/kit/kd_layout.dart' show UserAvatar;
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/status_pill.dart';

/// One applicant of a structured job (PRD §3.2 step 5): the facts, the work they chose, their answers, and the
/// client's own shortlist and decline. Never a score or a rank, and in the order they applied.
class ApplicantPanelCard extends StatelessWidget {
  final JobApplication app;
  final bool awardedHere;
  final bool canAct;
  final VoidCallback onPick;
  final VoidCallback onShortlist;
  final VoidCallback onDecline;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onMessage;

  const ApplicantPanelCard({super.key, required this.app, required this.awardedHere, required this.canAct, required this.onPick, required this.onShortlist, required this.onDecline, this.onOpenProfile, this.onMessage});

  @override
  Widget build(BuildContext context) {
    final panel = app.panel!;
    final t = panel.talent;
    final declined = app.status == 'declined';
    final shortlisted = app.status == 'shortlisted';
    final notSelected = app.status == 'notSelected';
    return Opacity(
      opacity: declined || notSelected ? .55 : 1,
      child: KdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  UserAvatar(name: t.fullName, photoUrl: t.photoUrl, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.fullName, style: AppTextStyles.title),
                        Text(t.headline ?? 'Applied ${formatAgo(app.createdAt)}', style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (awardedHere) const StatusPill('Picked', tone: KdTone.ok, icon: Icons.check_rounded),
                  if (shortlisted) const StatusPill('Shortlisted', tone: KdTone.brand, icon: Icons.bookmark_rounded),
                  if (declined) const StatusPill('Declined'),
                  if (notSelected) const StatusPill('Not selected'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in t.verifiedSkills) StatusPill('Verified: ${s.label}', tone: KdTone.ok, icon: Icons.verified_outlined),
                if (t.identityVerified) const StatusPill('Identity checked', tone: KdTone.ok),
                StatusPill(t.completedJobs == 0 ? 'No completed jobs yet' : '${t.completedJobs} job${t.completedJobs == 1 ? '' : 's'} done'),
                if (t.newOnKingDomain) StatusPill('New on ${AppBrand.name}'),
                if (panel.invited) const StatusPill('You invited them', tone: KdTone.brand),
                if (t.educationText != null && t.educationText!.isNotEmpty) StatusPill(t.educationText!),
                if (t.regionText != null && t.regionText!.isNotEmpty) StatusPill(t.regionText!),
              ],
            ),
            if (panel.answer != null && panel.answer!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Their answer', style: AppTextStyles.hint),
              const SizedBox(height: 2),
              Text(panel.answer!, style: AppTextStyles.bodyMedium),
            ],
            if (panel.pieces.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Work they chose to show', style: AppTextStyles.hint),
              for (final p in panel.pieces)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.title.isEmpty ? 'Untitled' : p.title, style: AppTextStyles.title),
                      if (p.role.isNotEmpty || p.madeOn.isNotEmpty) Text([p.role, p.madeOn].where((x) => x.isNotEmpty).join(' · '), style: AppTextStyles.hint),
                      if (p.brief.isNotEmpty) ...[const SizedBox(height: 4), Text(p.brief, style: AppTextStyles.bodySmall)],
                      if (p.files.isNotEmpty || (p.liveLink ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text([if (p.files.isNotEmpty) '${p.files.length} file${p.files.length == 1 ? '' : 's'}', if ((p.liveLink ?? '').isNotEmpty) 'live link'].join(' · '), style: AppTextStyles.hint),
                      ],
                    ]),
                  ),
                ),
            ],
            if (panel.screening.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final q in panel.screening) ...[
                Text(q.question, style: AppTextStyles.hint),
                const SizedBox(height: 2),
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(q.answer, style: AppTextStyles.bodyMedium)),
              ],
            ],
            if (onMessage != null && !declined) ...[
              const SizedBox(height: 6),
              KdButton.secondary(label: 'Message ${t.fullName.split(' ').first}', icon: Icons.chat_bubble_outline_rounded, height: AppDimensions.buttonHeightSm, onPressed: onMessage),
            ],
            if (canAct && !declined && !notSelected) ...[
              const SizedBox(height: 6),
              KdButton(label: 'Pick ${t.fullName.split(' ').first}', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: onPick),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: KdButton.secondary(label: shortlisted ? 'Remove from shortlist' : 'Shortlist', height: AppDimensions.buttonHeightSm, onPressed: onShortlist)),
                const SizedBox(width: 8),
                Expanded(child: KdButton.secondary(label: 'Decline', height: AppDimensions.buttonHeightSm, onPressed: onDecline)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
