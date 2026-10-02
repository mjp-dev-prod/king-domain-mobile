import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/contract_history.dart';
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';

/// Talent delivers (or re-delivers) the work. A delivery is a note for the
/// client plus the work itself: an image file, a web link, or both. Every
/// submit is kept as a numbered version (backend contractChanges.js), so a
/// resubmission shows the change the client asked for while you write.
class SubmitDeliverableScreen extends ConsumerStatefulWidget {
  final String jobId;

  const SubmitDeliverableScreen({super.key, required this.jobId});

  /// Mirrors the backend check (contractChanges.submitDelivery): web links only.
  static bool isWebLink(String text) => RegExp(r'^https?://[^\s/]+\.[^\s]+$', caseSensitive: false).hasMatch(text.trim());

  @override
  ConsumerState<SubmitDeliverableScreen> createState() => _SubmitDeliverableScreenState();
}

class _SubmitDeliverableScreenState extends ConsumerState<SubmitDeliverableScreen> {
  final _note = TextEditingController();
  final _link = TextEditingController();
  XFile? _file;
  bool _noteValid = false;

  @override
  void initState() {
    super.initState();
    _link.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    _link.dispose();
    super.dispose();
  }

  String get _linkText => _link.text.trim();
  bool get _linkBad => _linkText.isNotEmpty && !SubmitDeliverableScreen.isWebLink(_linkText);
  bool get _hasWork => _file != null || (_linkText.isNotEmpty && !_linkBad);

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, imageQuality: 90);
    if (file != null && mounted) setState(() => _file = file);
  }

  Future<void> _submit(Job job) async {
    final file = _file;
    try {
      await ref.read(jobsProvider.notifier).submitDeliverable(
            job.id,
            _note.text.trim(),
            url: _linkText.isEmpty ? null : _linkText,
            fileBytes: file == null ? null : await File(file.path).readAsBytes(),
            fileName: file?.name,
          );
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Delivered. ${job.clientName} has been told to review it.', kind: ToastKind.ok);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsProvider);
    final job = jobsAsync.valueOrNull?.where((j) => j.id == widget.jobId).firstOrNull;
    if (job == null) {
      return Scaffold(
        body: Center(
          child: jobsAsync.isLoading
              ? const CircularProgressIndicator()
              : ErrorState(
                  message: "Couldn't load this contract. Check your connection and try again.",
                  onRetry: () => ref.read(jobsProvider.notifier).refresh(),
                ),
        ),
      );
    }
    final history = ref.watch(contractHistoryProvider(job.id)).valueOrNull ?? const ContractHistory();
    final resubmitting = job.contractStatus == ContractStatus.changesRequested;
    final version = history.deliveries.length + 1;
    final round = history.latestChangeRound;
    // A bad link blocks sending even with a file attached: the server refuses it.
    final canSubmit = _noteValid && _hasWork && !_linkBad;

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 180),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              ContractHeader(
                title: resubmitting ? 'Deliver the revised version' : 'Deliver your work',
                sub: job.title,
                pill: StatusPill('Version $version', tone: KdTone.brand),
              ),
              if (resubmitting && round != null) ...[
                const SizedBox(height: 14),
                NoticeCard(
                  tone: KdTone.warn,
                  icon: Icons.edit_note_rounded,
                  title: 'What ${job.clientName} asked for',
                  trailing: 'Round ${round.round} of ${Job.maxChangeRounds}',
                  quote: round.reason,
                  waiting: job.changeDueAt == null ? null : 'Resubmit within ${timeLeft(job.changeDueAt!) ?? 'now'}',
                ),
              ],
              const SizedBox(height: 18),
              Text('THE WORK', style: AppTextStyles.label),
              const SizedBox(height: 8),
              _FilePicker(file: _file, onPick: _pick, onClear: () => setState(() => _file = null)),
              const SizedBox(height: 10),
              TextField(
                controller: _link,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Or a link: https://…',
                  prefixIcon: const Icon(Icons.link_rounded, color: AppColors.text3),
                  errorText: _linkBad ? 'Use a full web address starting with https://' : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add an image of the finished work, a link (Drive, Figma, GitHub…) for anything else, or both.',
                style: AppTextStyles.hint,
              ),
              ReasonField(
                controller: _note,
                label: 'Note to ${job.clientName}',
                hint: resubmitting
                    ? 'What you changed, point by point.'
                    : 'What you\'re delivering and anything they need to know to use it.',
                onValidChanged: (v) => setState(() => _noteValid = v),
              ),
              const SizedBox(height: 4),
              KdCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.text2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${job.clientName} reviews it next. Your payment is released when they approve; '
                        '${job.changeRoundsLeft > 0 ? 'they can ask for changes up to ${job.changeRoundsLeft} more time${job.changeRoundsLeft == 1 ? '' : 's'}.' : 'there are no change rounds left, so after this it\'s approve or an admin.'}',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ActionBar(
              children: [
                KdButton(
                  label: resubmitting ? 'Deliver version $version' : 'Deliver for review',
                  icon: Icons.send_rounded,
                  busyLabel: _file == null ? 'Delivering' : 'Uploading',
                  onPressed: canSubmit ? () => _submit(job) : null,
                ),
                if (!canSubmit)
                  Text(
                    !_hasWork ? 'Add an image or a link to deliver.' : _linkBad ? 'Fix the link, or clear it.' : 'Write a short note (at least 10 characters).',
                    style: AppTextStyles.hint,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePicker extends StatelessWidget {
  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onClear;
  const _FilePicker({required this.file, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final f = file;
    return AnimatedSwitcher(
      duration: AppMotion.state,
      child: f == null
          ? Pressable(
              key: const ValueKey('empty'),
              onTap: onPick,
              semanticLabel: 'Attach an image',
              child: Container(
                height: 120,
                decoration: BoxDecoration(color: AppColors.surface1, borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryText, size: 28),
                    const SizedBox(height: 8),
                    Text('Attach an image', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                    Text('PNG or JPG, up to 10 MB', style: AppTextStyles.hint),
                  ],
                ),
              ),
            )
          : ClipRRect(
              key: ValueKey(f.path),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(File(f.path), fit: BoxFit.cover, cacheWidth: 900, width: double.infinity),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(AppDimensions.radiusPill)),
                            child: Text(f.name, style: AppTextStyles.hint.copyWith(color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ChipButton(icon: Icons.swap_horiz_rounded, label: 'Replace', onTap: onPick),
                        const SizedBox(width: 6),
                        _ChipButton(icon: Icons.close_rounded, label: 'Remove', onTap: onClear),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ChipButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(color: AppColors.surface3, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: AppColors.text),
        ),
      );
}
