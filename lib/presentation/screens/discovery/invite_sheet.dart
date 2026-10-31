import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/api_client.dart';
import '../../../data/models/discovery.dart';
import '../../../data/models/job.dart';
import '../../providers/discovery_provider.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';

/// Invite one talent to a job: up to 20 per job, each valid for 72 hours. No contact details in the note (D18).
Future<void> showInviteSheet(BuildContext context, WidgetRef ref, {required Job job, required TalentCard talent}) async {
  final message = TextEditingController();
  await showKdSheet(
    context,
    builder: (sheet) => KdSheetBody(
      title: 'Invite ${talent.fullName.split(' ').first}?',
      lead: 'They are told now and have 72 hours to look. An invited talent can apply even if the job has paused. You can invite up to 20 people to one job.',
      children: [
        const SizedBox(height: 12),
        KdTextField(controller: message, label: 'A short note (optional)', hintText: 'Why their work fits', maxLines: 3),
        const SizedBox(height: 14),
        KdButton(
          label: 'Send invitation',
          busyLabel: 'Sending',
          onPressed: () async {
            try {
              await ref.read(discoveryActionsProvider).invite(job.id, talent.id, message: message.text);
            } on ApiException catch (e) {
              if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
              throw const ShownError();
            }
            if (!sheet.mounted) return;
            Navigator.of(sheet).pop();
            KdToast.show(sheet, 'Invited ${talent.fullName.split(' ').first}. They have 72 hours.');
          },
        ),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Not now', onPressed: () => Navigator.of(sheet).pop()),
      ],
    ),
  );
  // The sheet is still sliding away: dispose once it is gone, not while it is drawing the field.
  Future<void>.delayed(const Duration(milliseconds: 500), message.dispose);
}
