import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/sent_work_provider.dart';
import 'kd_button.dart';
import 'kd_card.dart';
import 'kd_image.dart';
import 'motion.dart';
import 'pressable.dart';

/// A link as it looks when opened, the way a chat app unfurls one: the page's picture, title and description, and the site
/// it belongs to. Shown for a person's own live link or "how it was made" link, so they can see what a reviewer will meet.
/// When the page can't be read it says why in words that tell them what to fix.
class LinkPreviewCard extends ConsumerWidget {
  final String url;
  /// "Live link", "How it was made": what this link is for.
  final String label;
  const LinkPreviewCard({super.key, required this.url, required this.label});

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn\'t open the link.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(linkPreviewProvider(url));
    return async.when(
      loading: () => KdCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          AspectRatio(aspectRatio: 1.91, child: Skeleton(height: double.infinity, radius: 0)),
          Padding(padding: EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(height: 12, width: 90), SizedBox(height: 10), Skeleton(height: 16, width: 220), SizedBox(height: 8), Skeleton(height: 12)])),
        ]),
      ),
      error: (_, _) => _Failed(url: url, label: label, reason: 'Couldn\'t check the link right now. Check your connection.', onOpen: () => _open(context), onRetry: () => ref.invalidate(linkPreviewProvider(url))),
      data: (p) {
        if (!p.ok) return _Failed(url: url, label: label, reason: p.reason ?? 'The page couldn\'t be read.', onOpen: () => _open(context), onRetry: () => ref.invalidate(linkPreviewProvider(url)));
        final host = p.host ?? Uri.tryParse(url)?.host ?? url;
        return Pressable(
          onTap: () => _open(context),
          semanticLabel: 'Open $label: ${p.title ?? host}',
          child: KdCard(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.image != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
                  child: AspectRatio(aspectRatio: 1.91, child: WorkImage(url: p.image, radius: 0, cacheWidth: 800, fallbackIcon: Icons.language_rounded)),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (p.favicon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(p.favicon!, width: 16, height: 16, errorBuilder: (_, _, _) => const Icon(Icons.language_rounded, size: 16, color: AppColors.text3))),
                      )
                    else
                      const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.language_rounded, size: 16, color: AppColors.text3)),
                    Expanded(child: Text((p.siteName ?? host).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.label)),
                    const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.text3),
                  ]),
                  const SizedBox(height: 8),
                  Text(p.kind == 'file' ? 'A file download' : (p.title ?? host), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.title),
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(p.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2, height: 1.4)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.ok),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Reachable. This is what a reviewer sees first.', style: AppTextStyles.hint)),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Failed extends StatelessWidget {
  final String url;
  final String label;
  final String reason;
  final VoidCallback onOpen;
  final VoidCallback onRetry;
  const _Failed({required this.url, required this.label, required this.reason, required this.onOpen, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      tone: KdTone.warn,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.link_off_rounded, size: 18, color: AppColors.warn),
          const SizedBox(width: 8),
          Expanded(child: Text('$label couldn\'t be previewed', style: AppTextStyles.title)),
        ]),
        const SizedBox(height: 4),
        Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.hint),
        const SizedBox(height: 6),
        Text(reason, style: AppTextStyles.bodySmall.copyWith(height: 1.4)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: KdButton.secondary(label: 'Try again', height: AppDimensions.buttonHeightSm, onPressed: onRetry)),
          const SizedBox(width: 10),
          Expanded(child: KdButton.secondary(label: 'Open it myself', icon: Icons.open_in_new_rounded, height: AppDimensions.buttonHeightSm, onPressed: onOpen)),
        ]),
      ]),
    );
  }
}
