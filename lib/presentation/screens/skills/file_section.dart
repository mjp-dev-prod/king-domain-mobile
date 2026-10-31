import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/debug_log.dart';
import '../../../data/api_client.dart';
import '../../../data/models/skill_submission.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../widgets/kit/evidence_viewer.dart' show formatBytes;
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/pressable.dart';

String roleName(FileRole r) => switch (r) {
  FileRole.output => 'finished work',
  FileRole.working => 'working files',
  FileRole.draft => 'drafts',
  FileRole.walkthrough => 'walkthrough',
};

IconData iconForType(String type) {
  if (type.startsWith('image/')) return Icons.image_outlined;
  if (type.startsWith('video/')) return Icons.videocam_outlined;
  if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
  return Icons.insert_drive_file_outlined;
}

/// One kind of file for one piece (or the walkthrough): what it is, why it's asked for, the files so far,
/// and adding more. Files go straight to storage; a failed upload leaves nothing half-made behind.
class FileSection extends ConsumerStatefulWidget {
  final String submissionId;
  final SubmissionDetail detail;
  final FileRole role;
  final String? pieceId;
  final List<SubmissionFile> files;
  final String title;
  final String hint;
  final bool single;

  const FileSection({
    super.key,
    required this.submissionId,
    required this.detail,
    required this.role,
    required this.files,
    required this.title,
    required this.hint,
    this.pieceId,
    this.single = false,
  });

  @override
  ConsumerState<FileSection> createState() => _FileSectionState();
}

class _FileSectionState extends ConsumerState<FileSection> {
  /// File name -> how much has gone (0 to 1), for files on their way.
  final Map<String, double> _sending = {};
  String? _problem;

  String? _check(PickedFile f) {
    final limit = widget.detail.limits[widget.role];
    if (limit == null) return null;
    if (!limit.types.contains(f.contentType)) return '${f.name}: that kind of file can\'t be added as ${roleName(widget.role)}.';
    if (f.size <= 0) return '${f.name} is empty.';
    if (f.size > limit.maxBytes) return '${f.name} is ${formatBytes(f.size)}. The limit here is ${formatBytes(limit.maxBytes)}.';
    return null;
  }

  Future<void> _upload(List<PickedFile> picked) async {
    final actions = ref.read(submissionActionsProvider);
    final problems = <String>[];
    for (final f in picked) {
      final bad = _check(f);
      kdLog('files', '${widget.role.name}: picked ${f.name} ${f.size} bytes ${f.contentType} -> ${bad ?? 'ok'}');
      if (bad != null) {
        problems.add(bad);
        continue;
      }
      setState(() => _sending[f.name] = 0);
      try {
        await actions.addFile(
          widget.submissionId,
          role: widget.role,
          pieceId: widget.pieceId,
          file: f,
          onProgress: (v) {
            if (mounted) setState(() => _sending[f.name] = v);
          },
        );
      } on ApiException catch (e) {
        problems.add('${f.name}: ${e.message}');
      } finally {
        if (mounted) setState(() => _sending.remove(f.name));
      }
    }
    if (mounted) setState(() => _problem = problems.isEmpty ? null : problems.join('\n'));
  }

  Future<void> _add() async {
    final gateway = ref.read(fileGatewayProvider);
    final isWalkthrough = widget.role == FileRole.walkthrough;
    final choice = await showKdSheet<String>(
      context,
      builder: (sheet) => KdSheetBody(
        title: isWalkthrough ? 'Add your walkthrough' : 'Add ${roleName(widget.role)}',
        lead: widget.hint,
        children: [
          const SizedBox(height: 12),
          if (isWalkthrough) ...[
            KdButton(label: 'Record now', icon: Icons.videocam_outlined, onPressed: () => Navigator.of(sheet).pop('record')),
            const SizedBox(height: 8),
            KdButton.secondary(label: 'Choose a video from your phone', onPressed: () => Navigator.of(sheet).pop('video')),
          ] else ...[
            KdButton(label: 'Photos or videos', icon: Icons.photo_library_outlined, onPressed: () => Navigator.of(sheet).pop('media')),
            const SizedBox(height: 8),
            KdButton.secondary(label: 'PDFs, documents and other files', onPressed: () => Navigator.of(sheet).pop('files')),
          ],
        ],
      ),
    );
    if (choice == null) return;
    final List<PickedFile> picked;
    switch (choice) {
      case 'record':
        final f = await gateway.recordVideo();
        picked = f == null ? const [] : [f];
      case 'video':
        final f = await gateway.pickVideo();
        picked = f == null ? const [] : [f];
      case 'media':
        picked = await gateway.pickMedia();
      default:
        picked = await gateway.pickDocuments();
    }
    if (picked.isEmpty) return;
    await _upload(widget.single ? [picked.first] : picked);
  }

  Future<void> _remove(SubmissionFile f) async {
    try {
      await ref.read(submissionActionsProvider).deleteFile(widget.submissionId, f.id);
      if (mounted) KdToast.show(context, 'Removed ${f.name}');
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.files.where((f) => f.ready).toList();
    final canAdd = !(widget.single && (ready.isNotEmpty || _sending.isNotEmpty));
    return KdCard(
      tone: ready.isNotEmpty ? KdTone.ok : KdTone.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(widget.title, style: AppTextStyles.title)),
            if (ready.isNotEmpty) const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.ok),
          ]),
          const SizedBox(height: 4),
          Text(widget.hint, style: AppTextStyles.hint),
          for (final f in ready) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(iconForType(f.contentType), size: 20, color: AppColors.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium),
                  Text(formatBytes(f.sizeBytes), style: AppTextStyles.hint),
                ]),
              ),
              Pressable(
                onTap: () => _remove(f),
                semanticLabel: 'Remove ${f.name}',
                child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.close_rounded, size: 20, color: AppColors.text3)),
              ),
            ]),
          ],
          for (final e in _sending.entries) ...[
            const SizedBox(height: 10),
            Text('Sending ${e.key}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: e.value == 0 ? null : e.value, minHeight: 6, backgroundColor: AppColors.surface3, color: AppColors.primary),
            ),
          ],
          if (_problem != null) ...[
            const SizedBox(height: 10),
            Text(_problem!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)),
          ],
          if (canAdd) ...[
            const SizedBox(height: 12),
            KdButton.secondary(
              label: ready.isEmpty ? (widget.role == FileRole.walkthrough ? 'Add the walkthrough' : 'Add files') : 'Add more',
              icon: Icons.add_rounded,
              height: AppDimensions.buttonHeightSm,
              onPressed: _sending.isNotEmpty ? null : _add,
            ),
          ],
        ],
      ),
    );
  }
}
