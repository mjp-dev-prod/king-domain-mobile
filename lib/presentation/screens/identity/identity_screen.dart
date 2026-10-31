import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/identity.dart';
import '../../providers/identity_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/consent_screen.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import 'identity_submit_screen.dart';

const _consent = ConsentDetails(
  title: 'Check your identity',
  purpose: 'So clients know you are a real person, and so money only ever reaches the person who did the work.',
  collected: [
    'Your name, date of birth and ID number (NIN or passport; CAC for a business)',
    'A photo of the document',
    'A 5 to 15 second video of your face',
  ],
  whoSees: 'Only the King Domain person who checks it. Never other users, never clients. Clients only see that you are verified.',
  keptFor: 'The documents are deleted when you delete your account. We keep the result (verified, your name and date of birth) while your account exists.',
  rights: 'You can ask what we hold, correct it, or delete your account at any time from your profile.',
  agreeLabel: 'I agree to this check',
);

/// Where a person stands on identity, and the one next step (PRD §3.1 step 4, D10 to D12, D47).
class IdentityScreen extends ConsumerWidget {
  const IdentityScreen({super.key});

  Future<void> _start(BuildContext context) async {
    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (c) => ConsentScreen(
          details: _consent,
          onAgree: () async => Navigator.of(c).pop(true),
          onDecline: () => Navigator.of(c).pop(false),
        ),
      ),
    );
    if (agreed != true || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IdentitySubmitScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityProvider);
    return Scaffold(
      body: identity.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load this. Check your connection and try again.", onRetry: () async => ref.invalidate(identityProvider))),
        data: (s) => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
          children: [
            ContractHeader(
              title: 'Verify your identity',
              sub: s.requiredForPaidActions ? 'Needed before you can apply for, post or award work.' : 'So clients trust you and payments reach the right person.',
              pill: _pill(s),
            ),
            const SizedBox(height: 16),
            RiseIn(child: _statusCard(context, ref, s)),
            if (s.minor || s.guardianNeeded) ...[
              const SizedBox(height: 12),
              RiseIn(delay: const Duration(milliseconds: 60), child: _GuardianCard(summary: s)),
            ],
            const SizedBox(height: 16),
            Text('Your documents are only seen by the person who checks them, and are deleted if you delete your account.', textAlign: TextAlign.center, style: AppTextStyles.hint),
          ],
        ),
      ),
    );
  }

  StatusPill _pill(IdentitySummary s) => switch (s.status) {
    IdentityStatus.verified => s.guardianNeeded ? const StatusPill('Guardian needed', tone: KdTone.warn) : const StatusPill('Verified', tone: KdTone.ok, icon: Icons.check_rounded),
    IdentityStatus.inReview => const StatusPill('Being checked', tone: KdTone.warn, pulse: true),
    IdentityStatus.notYet => const StatusPill('Not yet', tone: KdTone.warn),
    IdentityStatus.notStarted => const StatusPill('To do', tone: KdTone.brand),
  };

  Widget _statusCard(BuildContext context, WidgetRef ref, IdentitySummary s) {
    switch (s.status) {
      case IdentityStatus.verified:
        return NoticeCard(
          tone: KdTone.ok,
          icon: Icons.verified_user_outlined,
          title: 'You are verified',
          body: s.guardianNeeded ? 'One more step: your parent or guardian needs to confirm below before you can work.' : 'Clients see that you are verified. You can apply for and be paid for work.',
        );
      case IdentityStatus.inReview:
        return NoticeCard(
          tone: KdTone.warn,
          icon: Icons.hourglass_top_rounded,
          title: 'A person is checking it',
          body: 'This usually takes up to 2 days. We will tell you the moment it is done, by notification and email.',
          footnote: s.submittedAt == null ? null : 'Sent ${formatAgo(s.submittedAt!)}',
        );
      case IdentityStatus.notYet:
        return NoticeCard(
          tone: KdTone.warn,
          icon: Icons.refresh_rounded,
          title: 'Not verified yet',
          body: s.reason?.label ?? 'The check could not be completed.',
          quote: s.reason?.note,
          footnote: 'Nothing you sent is lost. Send it again with the fix.',
          actions: [KdButton(label: 'Send it again', height: AppDimensions.buttonHeightSm, onPressed: () => _start(context))],
        );
      case IdentityStatus.notStarted:
        return NoticeCard(
          tone: KdTone.brand,
          icon: Icons.verified_user_outlined,
          title: 'Takes about 3 minutes',
          body: 'You will need your NIN slip (or passport) and a phone camera. A person checks it by hand.',
          actions: [KdButton(label: 'Start', height: AppDimensions.buttonHeightSm, onPressed: () => _start(context))],
        );
    }
  }
}

/// Under 18: a parent or guardian confirms on their own phone (NDPA s.31; D12). The money still goes
/// to the young person's own account.
class _GuardianCard extends ConsumerWidget {
  final IdentitySummary summary;
  const _GuardianCard({required this.summary});

  Future<void> _ask(BuildContext context, WidgetRef ref, {GuardianInfo? previous}) async {
    await showKdSheet(
      context,
      builder: (sheet) => _GuardianForm(
        previous: previous,
        onSend: (name, email, relationship) async {
          try {
            await ref.read(identityActionsProvider).inviteGuardian(name: name, email: email, relationship: relationship);
          } on ApiException catch (e) {
            if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
            throw const ShownError();
          }
          if (!sheet.mounted) return;
          Navigator.of(sheet).pop();
          KdToast.show(sheet, 'Sent to $email');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = summary.guardian;
    if (g != null && g.confirmed) {
      return NoticeCard(tone: KdTone.ok, icon: Icons.family_restroom_rounded, title: '${g.name} has confirmed', body: 'Your parent or guardian has agreed. Your pay always goes to your own account.');
    }
    if (g != null) {
      return NoticeCard(
        tone: KdTone.warn,
        icon: Icons.mark_email_unread_outlined,
        title: 'Waiting for ${g.name}',
        body: 'We emailed ${g.email}. They open the link on their phone and tap Yes. The link works for 72 hours.',
        actions: [KdButton.secondary(label: 'Send the link again', height: AppDimensions.buttonHeightSm, onPressed: () => _ask(context, ref, previous: g))],
      );
    }
    return NoticeCard(
      tone: KdTone.brand,
      icon: Icons.family_restroom_rounded,
      title: 'Under 18: add a parent or guardian',
      body: 'They confirm once, on their own phone. You can start and finish your ID check now. Your pay always goes to your own account, never theirs.',
      actions: [KdButton(label: 'Add them', height: AppDimensions.buttonHeightSm, onPressed: () => _ask(context, ref))],
    );
  }
}

class _GuardianForm extends StatefulWidget {
  final GuardianInfo? previous;
  final Future<void> Function(String name, String email, String relationship) onSend;
  const _GuardianForm({required this.previous, required this.onSend});

  @override
  State<_GuardianForm> createState() => _GuardianFormState();
}

class _GuardianFormState extends State<_GuardianForm> {
  late final _name = TextEditingController(text: widget.previous?.name ?? '');
  late final _email = TextEditingController(text: widget.previous?.email ?? '');
  final _relationship = TextEditingController(text: 'Parent');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_name.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 2) {
      setState(() => _error = "Enter their full name.");
      throw const ShownError();
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      setState(() => _error = "Enter their email address.");
      throw const ShownError();
    }
    setState(() => _error = null);
    await widget.onSend(_name.text.trim(), _email.text.trim(), _relationship.text.trim().isEmpty ? 'Parent' : _relationship.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: 'Your parent or guardian',
      lead: 'We email them a link. They read what you are signing up for and confirm. They need their own email address.',
      children: [
        const SizedBox(height: 12),
        KdTextField(controller: _name, label: 'Their full name', textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        KdTextField(controller: _email, label: 'Their email', keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        KdTextField(controller: _relationship, label: 'How they are related to you'),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)),
        ],
        const SizedBox(height: 16),
        KdButton(label: 'Send the link', busyLabel: 'Sending', onPressed: _send),
      ],
    );
  }
}
