import 'package:flutter/material.dart';
import '../../../core/constants/app_brand.dart';
import '../../providers/push_service.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_sheet.dart';

/// The one-time explanation, shown after sign-in before Android's own prompt. Showing it counts as having
/// offered it: a person who swipes it away is not asked again at every start (the Profile has the switch).
void showPushPrompt(BuildContext context, PushService service) {
  service.declinePrompt();
  showKdSheet(
    context,
    builder: (sheet) => KdSheetBody(
      title: 'Stay in the loop',
      lead: 'Get a notification when you are picked, paid, or asked for something on a job. Nothing else.',
      children: [
        const SizedBox(height: 18),
        KdButton(
          label: 'Turn on',
          icon: Icons.notifications_active_outlined,
          onPressed: () async {
            Navigator.of(sheet).pop();
            await service.enable();
          },
        ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Not now', onPressed: () => Navigator.of(sheet).pop()),
      ],
    ),
  );
}

/// Tells the person how to change notifications in the phone's own settings. Android will not show its
/// prompt again once it has been refused for good, so the app says so instead of pretending to ask.
void showNotificationsSettingsInfo(BuildContext context, {required bool on}) {
  showKdSheet(
    context,
    builder: (sheet) => KdSheetBody(
      title: on ? 'Notifications are on' : 'Notifications are off',
      lead: on
          ? 'To turn them off, open your phone\'s Settings, then Apps, ${AppBrand.name}, then Notifications.'
          : 'To get them, open your phone\'s Settings, then Apps, ${AppBrand.name}, then Notifications, and switch them on.',
      children: [
        const SizedBox(height: 18),
        KdButton.secondary(label: 'Got it', onPressed: () => Navigator.of(sheet).pop()),
      ],
    ),
  );
}
