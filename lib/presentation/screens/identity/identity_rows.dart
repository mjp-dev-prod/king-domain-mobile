import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/identity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/identity_provider.dart';
import '../../widgets/kit/kd_card.dart' show KdTone;
import '../../widgets/kit/kd_layout.dart';
import 'identity_screen.dart';
import 'region_education_screen.dart';

void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

/// The two rows both profile tabs show: About you, and Verify your identity. Each says where it stands
/// and opens the screen that moves it forward (PRD §3.1 steps 2 and 4).
class IdentityGroup extends ConsumerWidget {
  const IdentityGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClient = ref.watch(authProvider).user?.role == 'client';
    final about = ref.watch(aboutYouProvider).valueOrNull;
    final identity = ref.watch(identityProvider).valueOrNull;

    final aboutDone = about?.isDoneFor(isClient) ?? false;
    final aboutSub = about == null
        ? 'Region and how you describe yourself'
        : aboutDone
            ? [if (about.region != null) about.region!.text, if (!isClient && about.education != null) about.education!.text].join(' · ')
            : 'Not set · add your region${isClient ? '' : ' and training'}';

    final (idSub, idTone) = switch (identity?.status) {
      IdentityStatus.verified => identity!.guardianNeeded ? ('Verified · waiting for your guardian', KdTone.warn) : ('Verified', KdTone.ok),
      IdentityStatus.inReview => ('Being checked', KdTone.warn),
      IdentityStatus.notYet => ('Not yet · tap to fix and send again', KdTone.warn),
      IdentityStatus.notStarted => ('Not started · takes about 3 minutes', KdTone.brand),
      null => ('Tap to check', KdTone.plain),
    };

    return ListGroup(
      rows: [
        ListRow(icon: Icons.place_outlined, title: 'About you', sub: aboutSub, subTone: aboutDone ? KdTone.plain : KdTone.warn, onTap: () => _open(context, const RegionEducationScreen())),
        ListRow(icon: Icons.verified_user_outlined, title: 'Verify your identity', sub: idSub, subTone: idTone, onTap: () => _open(context, const IdentityScreen())),
      ],
    );
  }
}
