import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/reputation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reputation_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/reputation_widgets.dart';
import '../../widgets/kit/status_pill.dart';

/// "Your reputation": what others see about you, how close each skill is to Proven, and the credentials you can take with
/// you. For a client it is what talents said about working with them. Counts and facts; never a score (D29).
class MyReputationScreen extends ConsumerWidget {
  const MyReputationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTalent = ref.watch(authProvider).user?.role != 'client';
    final async = ref.watch(myReputationProvider);
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: ErrorState(message: 'Couldn\'t load your reputation. Check your connection and try again.', onRetry: () async => ref.invalidate(myReputationProvider)))),
          ]),
        ),
        data: (rep) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myReputationProvider);
            ref.invalidate(credentialsProvider);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
            children: [
              ContractHeader(title: 'Your reputation', sub: isTalent ? 'What clients see, and what you can take with you' : 'What talents say about working with you', pill: const StatusPill('Facts, not scores')),
              const SizedBox(height: 12),
              if (isTalent && rep.talent != null) ..._talent(context, ref, rep.talent!) else if (rep.client != null) ..._client(rep.client!),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _client(ClientReputation c) => [
    KdCard(child: ClientReputationBlock(reputation: c)),
    if (c.reviews.isNotEmpty) ...[
      const SizedBox(height: 14),
      Text('What talents wrote', style: AppTextStyles.title),
      const SizedBox(height: 8),
      for (final r in c.reviews) Padding(padding: const EdgeInsets.only(bottom: 8), child: ReviewCard(review: r, canReport: true)),
    ],
  ];

  List<Widget> _talent(BuildContext context, WidgetRef ref, TalentReputation t) {
    final credentials = ref.watch(credentialsProvider);
    return [
      for (final p in t.proven) Padding(padding: const EdgeInsets.only(bottom: 10), child: RiseIn(child: _ProvenCard(p: p))),
      if (t.proven.isEmpty)
        const NoticeCard(tone: KdTone.plain, icon: Icons.workspace_premium_outlined, title: 'Proven comes after Verified', body: 'Get a skill verified first. Then three finished jobs in it, on time, with every client recommending you, make you Proven in that skill.'),
      const SizedBox(height: 6),
      Text('Your track record', style: AppTextStyles.title),
      const SizedBox(height: 8),
      TalentReputationSection(reputation: t, canReport: false),
      const SizedBox(height: 18),
      Text('Credentials you can take with you', style: AppTextStyles.title),
      const SizedBox(height: 4),
      Text('Finished jobs, verified skills and Proven levels, as Open Badges you can keep after you leave.', style: AppTextStyles.hint),
      const SizedBox(height: 10),
      credentials.when(
        loading: () => const SkeletonCard(),
        error: (_, _) => ErrorState(message: 'Couldn\'t load your credentials.', onRetry: () async => ref.invalidate(credentialsProvider)),
        data: (list) {
          if (list.credentials.isEmpty) {
            return const EmptyState(icon: Icons.badge_outlined, title: 'None yet', body: 'Your first one appears when a job is finished and paid, or a skill is verified.');
          }
          return Column(children: [
            if (!list.signingAvailable)
              const Padding(padding: EdgeInsets.only(bottom: 10), child: NoticeCard(tone: KdTone.warn, icon: Icons.hourglass_empty_rounded, title: 'Sharing isn\'t switched on yet', body: 'Your credentials are recorded and will be signed and shareable as soon as we finish setting up the issuer key.')),
            for (final c in list.credentials) Padding(padding: const EdgeInsets.only(bottom: 8), child: _CredentialCard(c: c)),
          ]);
        },
      ),
    ];
  }
}

class _ProvenCard extends StatelessWidget {
  final ProvenInfo p;
  const _ProvenCard({required this.p});

  @override
  Widget build(BuildContext context) {
    if (p.proven) {
      return NoticeCard(tone: KdTone.ok, icon: Icons.workspace_premium_outlined, title: 'Proven: ${p.skillLabel}', body: '${p.completed} finished jobs, on time, with every client recommending you. If a dispute is lost or a client stops recommending, this is re-checked.');
    }
    return NoticeCard(
      tone: KdTone.plain,
      icon: Icons.trending_up_rounded,
      title: '${p.skillLabel}: ${p.completed} of ${p.needed} jobs toward Proven',
      body: p.unmet.isEmpty ? null : 'Still needed:\n${p.unmet.map((u) => '- $u').join('\n')}',
    );
  }
}

class _CredentialCard extends StatelessWidget {
  final CredentialItem c;
  const _CredentialCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(c.kind == 'proven' ? Icons.workspace_premium_outlined : c.kind == 'skill_verified' ? Icons.verified_outlined : Icons.task_alt_rounded, size: 20, color: c.revoked ? AppColors.text3 : AppColors.primaryText),
          const SizedBox(width: 10),
          Expanded(child: Text(c.title, style: AppTextStyles.title)),
          if (c.revoked) const StatusPill('Revoked', tone: KdTone.bad) else if (c.signed) const StatusPill('Signed', tone: KdTone.ok) else const StatusPill('Not shareable yet'),
        ]),
        const SizedBox(height: 4),
        Text('${c.description} Issued ${formatAgo(c.issuedAt)}.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2)),
        if (c.revoked && c.revokedReason != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Revoked: ${c.revokedReason}', style: AppTextStyles.hint)),
        if (c.url != null && !c.revoked) ...[
          const SizedBox(height: 10),
          KdButton.secondary(label: 'Open the credential', icon: Icons.open_in_new_rounded, height: AppDimensions.buttonHeightSm, onPressed: () => launchUrl(Uri.parse('${c.url}/json'), mode: LaunchMode.externalApplication)),
        ],
      ]),
    );
  }
}
