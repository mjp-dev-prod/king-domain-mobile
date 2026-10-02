import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/contract_history.dart';
import '../../../data/models/job.dart';
import '../kit/kd_card.dart';
import '../kit/pressable.dart';
import '../kit/status_pill.dart';

/// Pieces shared by the talent's and the client's contract screens, built to
/// match prototypes/stage2-contract-flow.html.

/// Rebuilds its child every [every] so countdowns stay current.
class LiveClock extends StatefulWidget {
  final WidgetBuilder builder;
  final Duration every;
  const LiveClock({super.key, required this.builder, this.every = const Duration(seconds: 30)});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late final Timer _t = Timer.periodic(widget.every, (_) => setState(() {}));

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The status pill shown in a contract screen's header.
StatusPill contractStatusPill(ContractStatus status) => switch (status) {
  ContractStatus.awaitingPayment => const StatusPill('Waiting for payment', tone: KdTone.warn, pulse: true),
  ContractStatus.funded => const StatusPill('Paid · ready to start', tone: KdTone.ok, icon: Icons.lock_outline_rounded),
  ContractStatus.inProgress => const StatusPill('In progress', tone: KdTone.brand, pulse: true),
  ContractStatus.submitted => const StatusPill('In review', tone: KdTone.warn, pulse: true),
  ContractStatus.changesRequested => const StatusPill('Changes requested', tone: KdTone.warn, pulse: true),
  ContractStatus.disputed => const StatusPill('With an admin', tone: KdTone.bad, icon: Icons.balance_rounded),
  ContractStatus.approved => const StatusPill('Paid', tone: KdTone.ok, icon: Icons.check_rounded),
};

/// Screen header: back button + status pill, the job title and one sub line.
class ContractHeader extends StatelessWidget {
  final String title;
  final String sub;
  final StatusPill pill;
  const ContractHeader({super.key, required this.title, required this.sub, required this.pill});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canPop)
              Pressable(
                onTap: () => Navigator.of(context).maybePop(),
                semanticLabel: 'Back',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
                ),
              ),
            const Spacer(),
            pill,
          ],
        ),
        const SizedBox(height: 14),
        Text(title, style: AppTextStyles.h2),
        const SizedBox(height: 2),
        Text(sub, style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
      ],
    );
  }
}

String _bigLeft(Duration d) {
  final a = d.abs();
  final days = a.inDays, h = a.inHours % 24, m = a.inMinutes % 60;
  return days > 0 ? '${days}d ${h}h ${m}m' : '${h}h ${m}m';
}

/// The hero countdown to the delivery date, with a meter of time used.
class DeadlineCard extends StatelessWidget {
  final String eyebrow;
  final DateTime deadline;
  final DateTime? start;
  final String? footRight;
  final String? lateNote;

  const DeadlineCard({super.key, required this.eyebrow, required this.deadline, this.start, this.footRight, this.lateNote});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final left = deadline.difference(now);
    final late = left.isNegative;
    final total = start == null ? null : deadline.difference(start!);
    final used = total == null || total.inSeconds <= 0 ? null : (1 - left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return KdCard(
      hero: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text((late ? 'Delivery date passed' : eyebrow).toUpperCase(), style: AppTextStyles.label)),
              StatusPill(formatDeadline(deadline).split(',').first, icon: Icons.event_outlined),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: late ? 'Late by ${_bigLeft(left)}' : '${timeLeft(deadline)} left',
            child: ExcludeSemantics(
              child: Text(
                late ? 'Late ${_bigLeft(left)}' : _bigLeft(left),
                style: AppTextStyles.figure.copyWith(color: late ? AppColors.bad : AppColors.text),
              ),
            ),
          ),
          if (used != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: late ? 1 : used),
                duration: reduce ? Duration.zero : AppMotion.arrive,
                curve: AppMotion.ease,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: late ? AppColors.bad : AppColors.primary,
                  backgroundColor: AppColors.surface3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (start != null) Text('Paid ${formatDeadline(start!).split(',').first}', style: AppTextStyles.hint),
              const Spacer(),
              Flexible(
                child: Text(
                  late ? (lateNote ?? '') : (footRight ?? (used == null ? '' : '${((1 - used) * 100).round()}% of the time left')),
                  textAlign: TextAlign.right,
                  style: AppTextStyles.hint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A tinted notice card: icon + title + body, optional quote, waiting line,
/// footnote and actions. Every stage 2 state card is one of these.
class NoticeCard extends StatelessWidget {
  final KdTone tone;
  final IconData icon;
  final String title;
  final String? trailing;
  final String? body;
  final String? quote;
  final String? waiting;
  final String? footnote;
  final Widget? extra;
  final List<Widget> actions;

  const NoticeCard({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.trailing,
    this.body,
    this.quote,
    this.waiting,
    this.footnote,
    this.extra,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final ink = toneInk(tone);
    return KdCard(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: tone == KdTone.plain ? AppColors.text2 : ink),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTextStyles.title)),
              if (trailing != null) StatusPill(trailing!, tone: tone),
            ],
          ),
          ?extra,
          if (quote != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0x2E000000), borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
              child: Text('"$quote"', style: AppTextStyles.bodyMedium.copyWith(fontSize: 13.5)),
            ),
          ],
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
          ],
          if (waiting != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                PulseDot(color: ink),
                const SizedBox(width: 8),
                Expanded(child: Text(waiting!, style: AppTextStyles.bodySmall.copyWith(color: ink, fontWeight: FontWeight.w600))),
              ],
            ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 8),
            Text(footnote!, style: AppTextStyles.hint),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Two-segment progress for change rounds (done · current · not yet).
class RoundSteps extends StatelessWidget {
  final int current;
  final int total;
  const RoundSteps({super.key, required this.current, this.total = Job.maxChangeRounds});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          for (var r = 1; r <= total; r++) ...[
            if (r > 1) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: r < current ? AppColors.ok : r == current ? AppColors.warn : AppColors.surface3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every delivery version, newest selected; older versions stay viewable.
class VersionsCard extends StatefulWidget {
  final List<DeliveryVersion> versions;
  final String title;
  const VersionsCard({super.key, required this.versions, required this.title});

  @override
  State<VersionsCard> createState() => _VersionsCardState();
}

class _VersionsCardState extends State<VersionsCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final vs = widget.versions;
    final v = vs.firstWhere((d) => d.version == _selected, orElse: () => vs.last);
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 20, color: AppColors.text2),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.title, style: AppTextStyles.title)),
              StatusPill('${vs.length} version${vs.length == 1 ? '' : 's'}'),
            ],
          ),
          if (vs.length > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final d in vs) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Version ${d.version} · ${formatDeadline(d.submittedAt).split(',').first}'),
                        selected: d.version == v.version,
                        onSelected: (_) => setState(() => _selected = d.version),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          AnimatedSwitcher(
            duration: AppMotion.state,
            child: Column(
              key: ValueKey(v.version),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((v.note ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(v.note!, style: AppTextStyles.bodyMedium),
                ],
                if (v.fileUrl != null) _LinkRow(icon: Icons.attach_file_rounded, label: 'Open the file', url: v.fileUrl!),
                if ((v.url ?? '').isNotEmpty) _LinkRow(icon: Icons.link_rounded, label: v.url!, url: v.url!),
                const SizedBox(height: 10),
                Text('Delivered ${formatDeadline(v.submittedAt)} · versions are kept, never overwritten', style: AppTextStyles.hint),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  const _LinkRow({required this.icon, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Pressable(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryText),
              const SizedBox(width: 10),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600))),
              const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom area for a screen's main action(s), with the functional
/// fade the brand allows (content scrolling under the bar).
class ActionBar extends StatelessWidget {
  final List<Widget> children;
  const ActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: [0, .7, 1],
          colors: [AppColors.ground, AppColors.ground, Color(0x000D0A16)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 18, AppDimensions.gutter, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
            ],
          ),
        ),
      ),
    );
  }
}
