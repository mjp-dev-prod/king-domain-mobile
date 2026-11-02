import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/skill_submission.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import 'file_section.dart';

/// One piece of work: what it was, the person's part in it, and the files that show it (PRD §4.3).
/// The three kinds of file are asked for separately because each answers a different doubt: the finished work
/// shows what was made, and "how it was made" (a screenshot, a recording, a file or a link, in words for the skill)
/// that it was really made and not copied.
class PieceEditorScreen extends ConsumerStatefulWidget {
  final String submissionId;
  final String pieceId;
  const PieceEditorScreen({super.key, required this.submissionId, required this.pieceId});

  @override
  ConsumerState<PieceEditorScreen> createState() => _PieceEditorScreenState();
}

class _PieceEditorScreenState extends ConsumerState<PieceEditorScreen> {
  final _title = TextEditingController();
  final _brief = TextEditingController();
  final _role = TextEditingController();
  final _madeOn = TextEditingController();
  final _link = TextEditingController();
  final _process = TextEditingController();
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _brief, _role, _madeOn, _link, _process]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(SubmissionPiece p) {
    if (_loaded) return;
    _loaded = true;
    _title.text = p.title;
    _brief.text = p.brief;
    _role.text = p.role;
    _madeOn.text = p.madeOn;
    _link.text = p.liveLink;
    _process.text = p.processLink;
  }

  Future<void> _save() async {
    final link = _link.text.trim();
    final processLink = _process.text.trim();
    final linkOk = RegExp(r'^https?://\S+\.\S+$', caseSensitive: false);
    if (link.isNotEmpty && !linkOk.hasMatch(link)) {
      setState(() => _error = 'The live link must start with http:// or https://.');
      throw const ShownError();
    }
    if (processLink.isNotEmpty && !linkOk.hasMatch(processLink)) {
      setState(() => _error = 'The link that shows how you made it must start with http:// or https://.');
      throw const ShownError();
    }
    setState(() => _error = null);
    try {
      await ref.read(submissionActionsProvider).savePiece(
        widget.submissionId,
        widget.pieceId,
        title: _title.text.trim(),
        brief: _brief.text.trim(),
        role: _role.text.trim(),
        madeOn: _madeOn.text.trim(),
        liveLink: link,
        processLink: processLink,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Saved');
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final sure = await showKdSheet<bool>(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Remove this piece?',
        lead: 'Its details and every file you added to it are deleted.',
        children: [
          const SizedBox(height: 12),
          KdButton(label: 'Remove it', onPressed: () => Navigator.of(sheet).pop(true)),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep it', onPressed: () => Navigator.of(sheet).pop(false)),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(submissionActionsProvider).deletePiece(widget.submissionId, widget.pieceId);
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(submissionProvider(widget.submissionId));
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load this piece. Check your connection and try again.", onRetry: () async => ref.invalidate(submissionProvider(widget.submissionId)))),
        data: (d) {
          final piece = d.pieces.where((p) => p.id == widget.pieceId).firstOrNull;
          if (piece == null) {
            return const Center(child: EmptyState(icon: Icons.inbox_outlined, title: 'This piece is gone', body: 'It was removed. Go back to your submission.'));
          }
          _fill(piece);
          return ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
            children: [
              ContractHeader(title: piece.displayTitle, sub: 'Piece ${piece.position} of ${d.skillLabel}', pill: StatusPill(piece.detailsDone ? 'Details done' : 'Needs details', tone: piece.detailsDone ? KdTone.ok : KdTone.warn)),
              const SizedBox(height: 16),
              KdTextField(controller: _title, label: 'What is it called?', textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              KdTextField(controller: _brief, label: 'The brief: what was asked for, and for whom', maxLines: 4),
              const SizedBox(height: 12),
              KdTextField(controller: _role, label: 'Your part: all of it, or which part in a team', textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              KdTextField(controller: _madeOn, label: 'When you made it, e.g. March 2026', textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              KdTextField(controller: _link, label: 'Live link (optional)', hintText: 'https://', keyboardType: TextInputType.url),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)),
              ],
              const SizedBox(height: 14),
              KdButton(label: 'Save details', busyLabel: 'Saving', onPressed: _save),
              const SizedBox(height: 24),
              Text('Files for this piece', style: AppTextStyles.title),
              const SizedBox(height: 4),
              Text('Save your details first if you changed them. Files are saved as soon as they finish sending.', style: AppTextStyles.hint),
              const SizedBox(height: 12),
              RiseIn(
                child: FileSection(
                  submissionId: d.id,
                  detail: d,
                  role: FileRole.output,
                  pieceId: piece.id,
                  files: piece.filesOf(FileRole.output),
                  title: 'The finished work',
                  hint: piece.liveLink.trim().isNotEmpty ? 'You added a live link, so this is optional. Add the exported file as well if you have it.' : 'The exported video, the final design, the document. Required unless you add a live link.',
                ),
              ),
              const SizedBox(height: 12),
              KdCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Show how it was made', style: AppTextStyles.title),
                  const SizedBox(height: 4),
                  Text(d.howMadePrompt, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2)),
                  const SizedBox(height: 8),
                  for (final o in d.howMadeOptions) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('•  $o', style: AppTextStyles.bodySmall)),
                  const SizedBox(height: 4),
                  Text('One is enough, on one piece. Nothing here is judged for how neat it is: it only shows the work is yours.', style: AppTextStyles.hint),
                ]),
              ),
              const SizedBox(height: 12),
              FileSection(
                submissionId: d.id,
                detail: d,
                role: FileRole.working,
                pieceId: piece.id,
                files: piece.filesOf(FileRole.working),
                title: 'Screenshots, recordings or files',
                hint: 'Anything from the list above that you can add from your phone: a screenshot, a screen recording, a photo of your notes, or the file.',
              ),
              const SizedBox(height: 12),
              KdTextField(controller: _process, label: 'Or a link that shows it (optional)', hintText: 'https://github.com/you/project', keyboardType: TextInputType.url),
              const SizedBox(height: 6),
              Text('A GitHub, Figma or shared Google Docs link works. Save your details after adding it.', style: AppTextStyles.hint),
              const SizedBox(height: 24),
              KdButton.secondary(label: 'Remove this piece', onPressed: _remove),
            ],
          );
        },
      ),
    );
  }
}
