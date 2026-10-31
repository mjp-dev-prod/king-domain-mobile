import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_card.dart';
import 'kd_image.dart';
import 'pressable.dart';

enum EvidenceKind { image, video, file, link, text }

class EvidenceItem {
  final EvidenceKind kind;
  final String label;
  final String? url;
  final String? text;
  final int? sizeBytes;
  final String? thumbnailUrl;
  const EvidenceItem({required this.kind, required this.label, this.url, this.text, this.sizeBytes, this.thumbnailUrl});
}

String formatBytes(int bytes) {
  const kb = 1024, mb = kb * 1024, gb = mb * 1024;
  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).round()} KB';
  if (bytes < gb) return '${(bytes / mb).round()} MB';
  final g = bytes / gb;
  return '${g == g.roundToDouble() ? g.toStringAsFixed(0) : g.toStringAsFixed(1)} GB';
}

Future<void> _launch(Uri u) async {
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

/// Shows proof, start proofs, drafts and deliveries (PRD §4.2, §4.3, §4.9).
/// Light on data: only images render inline; videos and files show their size
/// and load only when tapped.
class EvidenceViewer extends StatelessWidget {
  final List<EvidenceItem> items;
  final Future<void> Function(Uri)? open;
  const EvidenceViewer({super.key, required this.items, this.open});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return KdCard(
        child: Row(children: [
          const Icon(Icons.attach_file_rounded, color: AppColors.text3),
          const SizedBox(width: 10),
          Text('Nothing attached', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)),
        ]),
      );
    }
    final go = open ?? _launch;
    return Column(
      children: [
        for (final item in items)
          Padding(padding: const EdgeInsets.only(bottom: AppDimensions.sm), child: _Tile(item: item, open: go)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final EvidenceItem item;
  final Future<void> Function(Uri) open;
  const _Tile({required this.item, required this.open});

  IconData get _icon => switch (item.kind) {
    EvidenceKind.image => Icons.image_outlined,
    EvidenceKind.video => Icons.play_circle_outline_rounded,
    EvidenceKind.file => Icons.description_outlined,
    EvidenceKind.link => Icons.link_rounded,
    EvidenceKind.text => Icons.notes_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (item.kind == EvidenceKind.text) {
      return KdCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.label, style: AppTextStyles.title),
          const SizedBox(height: 6),
          Text(item.text ?? '', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2, height: 1.5)),
        ]),
      );
    }
    final url = item.url;
    final meta = [
      if (item.kind == EvidenceKind.video) 'Video',
      if (item.kind == EvidenceKind.file) 'File',
      if (item.kind == EvidenceKind.link) Uri.tryParse(url ?? '')?.host ?? 'Link',
      if (item.sizeBytes != null) formatBytes(item.sizeBytes!),
      if (item.kind == EvidenceKind.video || item.kind == EvidenceKind.file) 'tap to open',
    ].join(' · ');
    return Pressable(
      onTap: url == null ? null : () => open(Uri.parse(url)),
      semanticLabel: item.label,
      child: KdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.kind == EvidenceKind.image && url != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                child: AspectRatio(aspectRatio: 4 / 3, child: WorkImage(url: url)),
              ),
              const SizedBox(height: 10),
            ],
            Row(children: [
              Icon(_icon, size: 20, color: AppColors.primaryText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.label, style: AppTextStyles.title),
                  if (meta.isNotEmpty) Text(meta, style: AppTextStyles.hint),
                ]),
              ),
              if (url != null && item.kind != EvidenceKind.image) const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.text3),
            ]),
          ],
        ),
      ),
    );
  }
}
