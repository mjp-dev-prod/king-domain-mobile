import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/discovery.dart';
import '../../../data/models/job.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/brief/brief_form.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../packages/job_questions_section.dart';
import '../../widgets/kit/reputation_widgets.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import '../discovery/apply_screen.dart';
import '../skills/skills_hub_screen.dart';
import '../payments/payout_account_screen.dart';
import 'job_feed_screen.dart' show canApplyTo;

/// T5 — Job detail (prototypes/palette-explorer.html, screen 02). What the
/// job is, what it pays and by when, and whether this talent can apply,
/// stated plainly. Applying shows exactly what the client will see.
///
/// Only real data: there is no client verification or rating system yet, so
/// the client card shows a name and nothing invented.
class JobDetailScreen extends ConsumerWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    final cached = jobsAsync.valueOrNull?.where((j) => j.id == jobId).firstOrNull;
    // A job the talent has not applied to is not in their own list: fetch it. A structured job also brings the
    // client's facts and any invitation, so it is fetched even when cached.
    final fetch = (cached == null && !jobsAsync.isLoading) || (cached?.isStructured ?? false);
    final detailAsync = fetch ? ref.watch(jobDetailProvider(jobId)) : null;
    final detail = detailAsync?.valueOrNull;
    final job = detail?.job ?? cached;
    final profile = ref.watch(talentProfileProvider).valueOrNull;
    final hub = ref.watch(skillHubProvider).valueOrNull;

    if (job == null) {
      final loading = jobsAsync.isLoading || (detailAsync?.isLoading ?? false);
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.gutter),
            child: loading
                ? const Column(children: [SizedBox(height: 60), SkeletonCard(), SizedBox(height: 12), SkeletonCard()])
                : Column(
                    children: [
                      Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
                      ErrorState(
                        message: 'Couldn\'t load this job.',
                        onRetry: () async {
                          ref.invalidate(jobDetailProvider(jobId));
                          await ref.read(jobsProvider.notifier).refresh();
                        },
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    final verified = canApplyTo(job, hub: hub);
    final hasPayout = profile?.payoutAccount != null;
    final applied = job.applicationStatus != JobApplicationStatus.notApplied;
    final filled = job.awardedApplicationId != null;
    final closed = job.closed;

    final cards = <Widget>[
      _Hero(job: job),
      ?_invitationBanner(detail?.invitation),
      ?_gate(context, job, verified: verified, hasPayout: hasPayout, applied: applied, invited: detail?.invitation != null),
      if (job.isStructured) _BriefCard(job: job),
      KdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About the job', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text(job.description, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2, height: 1.6)),
          ],
        ),
      ),
      KdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(name: job.clientName, photoUrl: job.clientPhotoUrl, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.clientName, style: AppTextStyles.title),
                      Text('Client · pays into ${AppBrand.name} before you start', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (detail != null) ...[const SizedBox(height: 12), const Divider(), const SizedBox(height: 10), _ClientFacts(record: detail.clientRecord)],
          ],
        ),
      ),
      if (job.isStructured) JobQuestionsSection(job: job, isClient: false),
      if (job.isStructured) const _SafetyNote(),
    ];

    final StatusPill? appliedPill = closed
        ? const StatusPill('Closed')
        : switch (job.applicationStatus) {
            JobApplicationStatus.pending => const StatusPill('Applied', tone: KdTone.brand),
            JobApplicationStatus.accepted => const StatusPill('You were selected', tone: KdTone.ok, icon: Icons.check_rounded),
            JobApplicationStatus.rejected => const StatusPill('Not selected'),
            JobApplicationStatus.notApplied => null,
          };

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 200),
            children: [
              ContractHeader(
                title: job.title,
                sub: 'Posted ${formatAgo(job.postedAt)}',
                pill: appliedPill ?? StatusPill(job.category, tone: KdTone.brand),
              ),
              for (var i = 0; i < cards.length; i++)
                Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 60 * i), child: cards[i])),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ActionBar(
              children: [
                if (!applied && !filled && !closed)
                  KdButton(
                    label: !job.isStructured
                        ? 'Not open for applications'
                        : !verified
                        ? 'Verify this skill to apply'
                        : !hasPayout
                            ? 'Add a payout account to apply'
                            : (job.paused && detail?.invitation == null)
                                ? 'Applications are paused'
                                : 'Apply for this job',
                    onPressed: job.isStructured && verified && hasPayout && (!job.paused || detail?.invitation != null)
                        ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApplyScreen(job: job)))
                        : null,
                  ),
                if (job.applicationStatus == JobApplicationStatus.pending)
                  Text('${job.clientName} will see your application with your verified proof.', textAlign: TextAlign.center, style: AppTextStyles.hint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The one thing standing between this talent and applying, if anything.
  Widget? _invitationBanner(InvitationInfo? i) {
    if (i == null) return null;
    final left = timeLeft(i.expiresAt);
    return NoticeCard(
      tone: KdTone.brand,
      icon: Icons.mail_outline_rounded,
      title: 'The client invited you',
      body: left == null ? 'This invitation has run out.' : 'Open for $left. An invited talent can apply even when the job is paused.',
      quote: i.message,
    );
  }

  Widget? _gate(BuildContext context, Job job, {required bool verified, required bool hasPayout, required bool applied, bool invited = false}) {
    if (job.paused && !applied && !invited && !job.closed) {
      return NoticeCard(
        tone: KdTone.warn,
        icon: Icons.pause_circle_outline_rounded,
        title: 'Applications are paused',
        body: job.pausedReason == 'applicants'
            ? 'This job has all ${job.applicantCap} applications it can take, so the client can look at them properly.'
            : 'This job has been open for 5 days, so applications are paused. Save a search to be told about similar jobs.',
      );
    }
    if (job.closed) {
      return NoticeCard(
        tone: KdTone.plain,
        icon: Icons.block_outlined,
        title: 'This job is closed',
        body: '${job.clientName} closed it, so it isn\'t taking applications.',
      );
    }
    if (applied) return null;
    if (!job.isStructured) {
      return const NoticeCard(
        tone: KdTone.plain,
        icon: Icons.history_toggle_off_rounded,
        title: 'This job can\'t take applications',
        body: 'It was posted before jobs asked for a skill, so you can\'t apply to it. Other jobs in the list are open.',
      );
    }
    if (!verified) {
      return NoticeCard(
        tone: KdTone.plain,
        icon: Icons.lock_outline_rounded,
        title: 'Verify ${job.skillOrCategory} to apply',
        body: 'Send two or three pieces of real work. Two reviewers score it, and a person checks it is yours. Then you can apply.',
        actions: [
          KdButton(
            label: 'Your skills',
            variant: KdButtonVariant.soft,
            height: AppDimensions.buttonHeightSm,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkillsHubScreen())),
          ),
        ],
      );
    }
    if (!hasPayout) {
      return NoticeCard(
        tone: KdTone.warn,
        icon: Icons.account_balance_outlined,
        title: 'Add a payout account to apply',
        body: 'It\'s where you\'re paid when the client approves your work.',
        actions: [
          KdButton(
            label: 'Add bank account',
            variant: KdButtonVariant.soft,
            height: AppDimensions.buttonHeightSm,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutAccountScreen())),
          ),
        ],
      );
    }
    return NoticeCard(
      tone: KdTone.ok,
      icon: Icons.verified_outlined,
      title: 'You can apply',
      body: 'You\'re verified in ${job.skillOrCategory}. The client sees the work you choose with your application.',
    );
  }

}

/// The budget (in gold: money's one colour), delivery time, applicants and
/// the agreed change limit.
class _Hero extends StatelessWidget {
  final Job job;
  const _Hero({required this.job});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.hint),
            const SizedBox(height: 2),
            Text(value, style: AppTextStyles.title.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
    return KdCard(
      hero: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatMoney(job.budget, job.currency), style: AppTextStyles.figure.copyWith(color: AppColors.money)),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(job.isStructured && job.jobType != JobType.oneDelivery ? '${job.jobType.label.toLowerCase()}${job.jobType.priceNote}' : 'paid to you when the client approves', style: AppTextStyles.bodySmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile('Delivery', job.deliveryDays == null ? 'Agree with client' : '${job.deliveryDays} day${job.deliveryDays == 1 ? '' : 's'}'),
              const SizedBox(width: 8),
              tile('Applied', job.isStructured ? '${job.applicationCount} of ${job.applicantCap}' : '${job.applicationCount}'),
              const SizedBox(width: 8),
              tile('Changes', 'Up to ${Job.maxChangeRounds}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// The structured brief, in the order the form asked for it. This is what the work is judged against.
class _BriefCard extends StatelessWidget {
  final Job job;
  const _BriefCard({required this.job});

  // In the order the forms ask. Keys from briefs written before 2026-11-07 are kept so older jobs still read.
  static const _labels = {
    'deliverables': 'Wanted',
    'designKind': 'Kind of design',
    'writingKind': 'Kind of writing',
    'siteKind': 'What is needed',
    'quantity': 'How many',
    'formats': 'Formats',
    'dimensions': 'Size or where it is used',
    'concepts': 'First ideas to choose from',
    'files': 'Files delivered',
    'durationSeconds': 'Length (seconds)',
    'aspectRatio': 'Shape',
    'rawFootage': 'Footage',
    'extras': 'Included',
    'projectFile': 'Editable project file',
    'platforms': 'Platforms',
    'postsPerWeek': 'Posts a week',
    'contentBy': 'Who makes the content',
    'postsForYou': 'Talent posts for the client',
    'replies': 'Replying to comments and messages',
    'report': 'Monthly report',
    'wordCount': 'Words each',
    'tone': 'Tone',
    'keywords': 'Keywords',
    'byline': 'Whose name goes on it',
    'deliveredAs': 'Delivered as',
    'pages': 'Pages or screens',
    'pageList': 'Which pages',
    'features': 'Features',
    'products': 'Products to add',
    'builtWith': 'Built with',
    'hosting': 'Domain and hosting',
    'stack': 'Technology',
    'designFiles': 'Design files or a site to follow',
    'handover': 'At the end the client gets',
    'brandNotes': 'Brand notes',
    'brandVoice': 'Brand voice',
    'sources': 'Sources',
    'usageRights': 'Use of the work',
    'revisionsIncluded': 'Rounds of changes included',
    'clientFiles': 'Client provides',
    'references': 'Examples',
    'months': 'Months',
    'monthlyScope': 'Each month',
    'hourlyRate': 'Rate per hour',
    'weeklyCapHours': 'Most hours a week',
    'weeks': 'Weeks',
  };

  String _value(String key, Object? v) {
    if (key == 'hourlyRate') return formatMoney(num.tryParse('$v') ?? 0, job.currency);
    return briefValueText(key, v);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      // In the form's order (the labels list), not the order the server happened to store them.
      for (final key in _labels.keys)
        if (job.brief[key] != null && briefValueText(key, job.brief[key]).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_labels[key]!, style: AppTextStyles.hint),
              Text(_value(key, job.brief[key]), style: AppTextStyles.bodyMedium),
            ]),
          ),
    ];
    final milestones = (job.brief['milestones'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The brief', style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text('The work is judged against this, so read it closely.', style: AppTextStyles.hint),
          const SizedBox(height: 12),
          ...rows,
          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Milestones', style: AppTextStyles.hint),
            for (var i = 0; i < milestones.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Expanded(child: Text('${i + 1}. ${milestones[i]['title']} · ${milestones[i]['days']} days', style: AppTextStyles.bodyMedium)),
                  Text(formatMoney(num.tryParse('${milestones[i]['amount']}') ?? 0, job.currency), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.money)),
                ]),
              ),
          ],
          if (job.screeningQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('You will be asked', style: AppTextStyles.hint),
            for (final q in job.screeningQuestions) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $q', style: AppTextStyles.bodyMedium)),
          ],
        ],
      ),
    );
  }
}

/// Real facts about the client (D19). Ratings and review speed wait for reviews to exist.
class _ClientFacts extends StatelessWidget {
  final ClientRecord record;
  const _ClientFacts({required this.record});

  @override
  Widget build(BuildContext context) {
    final paid = record.paidOut.isEmpty ? 'Nothing paid out yet' : '${record.paidOut.map((p) => formatMoney(p.amount, p.currency)).join(' and ')} paid out';
    final since = record.memberSince == null ? null : 'Member since ${formatDeadline(record.memberSince!).split(',').first}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (record.identityVerified) const StatusPill('Identity verified', tone: KdTone.ok, icon: Icons.verified_outlined) else const StatusPill('Identity not verified yet'),
          StatusPill('${record.jobsPosted} posted'),
          StatusPill('${record.jobsHired} hired'),
          StatusPill('${record.jobsCompleted} completed'),
        ]),
        const SizedBox(height: 8),
        Text([paid, ?since].join(' · '), style: AppTextStyles.hint),
        const SizedBox(height: 8),
        ClientReputationBlock(reputation: record.reputation),
      ],
    );
  }
}

/// "A talent never pays anyone" on every job (D18).
class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) => const NoticeCard(
    tone: KdTone.plain,
    icon: Icons.shield_outlined,
    title: 'You never pay anyone',
    body: 'Nobody on King Domain should ask you for money, a fee or a deposit. Keep everything inside the app, and report anything that asks otherwise.',
  );
}
