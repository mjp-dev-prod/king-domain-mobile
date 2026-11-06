import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/contract_extras_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../providers/push_gateway.dart';
import '../../providers/push_service.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import '../shell/profile_tabs.dart' show confirmSignOut;
import 'address_sheet.dart';
import 'currency_sheet.dart';
import 'delete_account_sheet.dart';
import 'notifications_sheet.dart';
import 'privacy_link.dart';

/// Everything that is a setting rather than a part of your profile, in one place and grouped by what it affects: what
/// reaches you, how things are shown, what this phone downloads, how to reach you, and the account itself. The profile
/// tab keeps only the things that are about your work.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _notifications(BuildContext context, WidgetRef ref, PushPermission permission) async {
    if (permission == PushPermission.granted) return showNotificationsSettingsInfo(context, on: true);
    if (permission == PushPermission.denied) return showNotificationsSettingsInfo(context, on: false);
    final result = await ref.read(pushServiceProvider).enable();
    ref.invalidate(pushPermissionProvider);
    // Refused again: Android may not show its prompt a second time, so say where the switch is.
    if (result != PushPermission.granted && context.mounted) showNotificationsSettingsInfo(context, on: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(pushPermissionProvider).valueOrNull;
    final dataSaver = ref.watch(dataSaverProvider);
    final email = ref.watch(authProvider).user?.email;
    void setSaver(bool v) => ref.read(dataSaverProvider.notifier).set(v);

    Widget section(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(top: 22),
      child: RiseIn(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title.toUpperCase(), style: AppTextStyles.label)),
          ListGroup(rows: rows),
        ]),
      ),
    );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
        children: [
          Row(children: [
            IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 4),
            Text('Settings', style: AppTextStyles.h1),
          ]),
          // Hidden on a build or phone without Firebase: there is nothing to switch.
          if (permission != null && permission != PushPermission.unavailable)
            section('Notifications', [
              ListRow(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                sub: switch (permission) {
                  PushPermission.granted => 'On. We tell you about jobs, messages and money.',
                  PushPermission.notAsked => 'Off · tap to turn on',
                  _ => 'Off · turn on in your phone\'s settings',
                },
                subTone: permission == PushPermission.granted ? KdTone.ok : KdTone.plain,
                onTap: () => _notifications(context, ref, permission),
              ),
            ]),
          section('Display', [
            ListRow(
              icon: Icons.currency_exchange_rounded,
              title: 'Money shown in',
              sub: switch (ref.watch(displayCurrencyProvider).valueOrNull) { 'USD' => 'Dollars, with naira amounts marked "about"', 'NGN' => 'Naira, with dollar amounts marked "about"', _ => 'Naira or dollars' },
              onTap: () => showCurrencySheet(context),
            ),
          ]),
          section('Data', [
            ListRow(
              icon: Icons.data_saver_on_rounded,
              title: 'Data saver',
              sub: dataSaver ? 'On. Photos and files in messages wait until you tap them.' : 'Off. Photos in messages load as they arrive.',
              subTone: dataSaver ? KdTone.ok : KdTone.plain,
              onTap: () => setSaver(!dataSaver),
              trailing: Semantics(label: 'Data saver', child: Switch(value: dataSaver, onChanged: setSaver, activeTrackColor: AppColors.primary)),
            ),
          ]),
          section('Privacy and safety', [
            ListRow(icon: Icons.place_outlined, title: 'Where we can reach you', sub: 'Only used if something serious goes wrong on a job', onTap: () => showAddressSheet(context)),
            ListRow(icon: Icons.privacy_tip_outlined, title: 'Privacy policy', sub: 'How we handle your data', onTap: () => openPrivacyPolicy(context)),
          ]),
          section('Account', [
            ListRow(icon: Icons.logout_rounded, title: 'Sign out', sub: email == null || email.isEmpty ? null : 'Signed in as $email', onTap: () => confirmSignOut(context, ref)),
            ListRow(icon: Icons.person_remove_outlined, title: 'Delete account', sub: 'Removes your account and what is on it', danger: true, onTap: () => showDeleteAccountSheet(context)),
          ]),
        ],
      ),
    );
  }
}
