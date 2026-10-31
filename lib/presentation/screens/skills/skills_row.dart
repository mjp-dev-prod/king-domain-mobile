import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/skill_submission.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../widgets/kit/kd_card.dart' show KdTone;
import '../../widgets/kit/kd_layout.dart';
import 'skills_hub_screen.dart';

/// The talent profile row that opens the skills hub, saying where the person stands (PRD §3.1 step 3).
class SkillsRow extends ConsumerWidget {
  const SkillsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(skillHubProvider).valueOrNull;
    final verified = hub?.skills.where((s) => s.state == SkillState.verified).length ?? 0;
    final waiting = hub?.skills.where((s) => s.state == SkillState.inReview).length ?? 0;
    final (sub, tone) = hub == null
        ? ('Prove what you can do', KdTone.plain)
        : verified > 0
            ? ('$verified verified${waiting > 0 ? ' · $waiting in review' : ''}', KdTone.ok)
            : waiting > 0
                ? ('$waiting in review', KdTone.warn)
                : ('None verified yet · tap to start', KdTone.brand);
    return ListGroup(
      rows: [
        ListRow(
          icon: Icons.workspace_premium_outlined,
          title: 'Your skills',
          sub: sub,
          subTone: tone,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkillsHubScreen())),
        ),
      ],
    );
  }
}
