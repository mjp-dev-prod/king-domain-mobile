import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/sent_work.dart';
import '../../providers/sent_work_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/evidence_viewer.dart' show formatBytes;
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/link_preview_card.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';
import 'media_viewer.dart';

void openSentWork(BuildContext context, String submissionId, {String? focusPieceId}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => SentWorkScreen(submissionId: submissionId, focusPieceId: focusPieceId)));
}

/// The way in from a submission's waiting and result screens.
class SeeEverythingButton extends StatelessWidget {
  final String submissionId;
  const SeeEverythingButton({super.key, required this.submissionId});

  @override
  Widget build(BuildContext context) => KdButton.secondary(label: 'See your submission', icon: Icons.visibility_outlined, height: AppDimensions.buttonHeightSm, onPressed: () => openSentWork(context, submissionId));
}

/// Everything a person sent for a skill, laid out to be looked at (PRD §4.3): what was asked and whether it is all there, then
/// each piece with its brief, its finished work, how it was made, its links as they look when opened, and plain advice;
/// then the walkthrough, with its real length, and the declaration. Files open in a gallery or a proper video player.
/// Read-only: a sent submission can't be changed, so this is for looking and for knowing what the checker will see.
class SentWorkScreen extends ConsumerStatefulWidget {
  final String submissionId;
  /// Scrolls to this piece when the screen opens (the row that was tapped).
  final String? focusPieceId;
  const SentWorkScreen({super.key, required this.submissionId, this.focusPieceId});

  @override
  ConsumerState<SentWorkScreen> createState() => _SentWorkScreenState();
}

class _SentWorkScreenState extends ConsumerState<SentWorkScreen> {
  final Map<String, GlobalKey> _keys = {};
  bool _scrolled = false;

  void _scrollToFocus() {
    final id = widget.focusPieceId;
    if (_scrolled || id == null) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic, alignment: .02);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sentWorkProvider(widget.submissionId));
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: ErrorState(message: 'Couldn\'t load what you sent. Check your connection and try again.', onRetry: () async => ref.invalidate(sentWorkProvider(widget.submissionId))))),
          ]),
        ),
        data: (w) {
          _scrollToFocus();
          return RefreshIndicator(
            // Pulling down also gets fresh links: the ones for your files expire after about an hour.
            onRefresh: () async => ref.invalidate(sentWorkProvider(widget.submissionId)),
            child: ListView(
              padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 60),
              children: [
                ContractHeader(
                  title: 'Your submission',
                  sub: '${w.skillLabel}${w.submittedAt == null ? '' : ' · sent ${formatAgo(w.submittedAt!)}'}',
                  pill: StatusPill(w.verdict == 'gaps' ? 'Something is missing' : 'Complete', tone: w.verdict == 'gaps' ? KdTone.warn : KdTone.ok, icon: w.verdict == 'gaps' ? Icons.error_outline_rounded : Icons.check_rounded),
                ),
                const SizedBox(height: 12),
                RiseIn(child: _Summary(w: w)),
                const SizedBox(height: 12),
                RiseIn(delay: const Duration(milliseconds: 60), child: _Requirements(w: w)),
                for (var i = 0; i < w.pieces.length; i++) ...[
                  const SizedBox(height: 16),
                  RiseIn(delay: Duration(milliseconds: 80 + 50 * i), child: KeyedSubtree(key: _keys.putIfAbsent(w.pieces[i].id, GlobalKey.new), child: _PieceCard(piece: w.pieces[i], howMadePrompt: w.howMadePrompt))),
                ],
                const SizedBox(height: 16),
                RiseIn(delay: const Duration(milliseconds: 200), child: _WalkthroughCard(files: w.walkthrough)),
                const SizedBox(height: 12),
                RiseIn(delay: const Duration(milliseconds: 240), child: _Declaration(w: w)),
                const SizedBox(height: 14),
                Text('Your files open through private links that expire after about an hour. If one stops working, pull down to refresh.', textAlign: TextAlign.center, style: AppTextStyles.hint),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── The top of the screen ──

class _Summary extends StatelessWidget {
  final SentWork w;
  const _Summary({required this.w});

  @override
  Widget build(BuildContext context) {
    final gaps = w.verdict == 'gaps';
    return NoticeCard(
      tone: gaps ? KdTone.warn : KdTone.ok,
      icon: gaps ? Icons.error_outline_rounded : Icons.verified_outlined,
      title: w.headline,
      body: w.detail,
    );
  }
}

class _Requirements extends StatelessWidget {
  final SentWork w;
  const _Requirements({required this.w});

  @override
  Widget build(BuildContext context) {
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What was asked, and why', style: AppTextStyles.title),
        const SizedBox(height: 4),
        Text('The person who checks your work looks for each of these. You can see whether it is there, and why we ask.', style: AppTextStyles.hint),
        const SizedBox(height: 12),
        for (final r in w.requirements)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(r.done ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 20, color: r.done ? AppColors.ok : AppColors.bad),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  if (r.why != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(r.why!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2, height: 1.4))),
                ]),
              ),
            ]),
          ),
        if (w.howMadeOptions.isNotEmpty) ...[
          const Divider(height: 8),
          const SizedBox(height: 8),
          Text('For ${w.skillLabel}, "how it was made" could be:', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final o in w.howMadeOptions) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('•  $o', style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2))),
        ],
      ]),
    );
  }
}

// ── One piece ──

class _PieceCard extends StatelessWidget {
  final SentPiece piece;
  final String howMadePrompt;
  const _PieceCard({required this.piece, required this.howMadePrompt});

  @override
  Widget build(BuildContext context) {
    final hasHowMade = piece.howMade.isNotEmpty || piece.processLink.isNotEmpty;
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Text('${piece.position}', style: AppTextStyles.label.copyWith(color: AppColors.primaryText)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(piece.displayTitle, style: AppTextStyles.h3)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (piece.role.trim().isNotEmpty) StatusPill(piece.role.trim(), icon: Icons.person_outline_rounded),
          if (piece.madeOn.trim().isNotEmpty) StatusPill(piece.madeOn.trim(), icon: Icons.event_outlined),
        ]),
        const _Gap(),
        const _Label('The brief'),
        Text(piece.brief.trim().isEmpty ? 'Not given.' : piece.brief.trim(), style: AppTextStyles.bodyMedium.copyWith(height: 1.5, color: piece.brief.trim().isEmpty ? AppColors.text3 : AppColors.text)),
        const _Gap(),
        const _Label('The finished work'),
        if (piece.finished.isEmpty && piece.liveLink.isEmpty) Text('Nothing was added.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)),
        _Files(files: piece.finished),
        if (piece.liveLink.isNotEmpty) ...[
          if (piece.finished.isNotEmpty) const SizedBox(height: 10),
          LinkPreviewCard(url: piece.liveLink, label: 'The live link'),
        ],
        const _Gap(),
        const _Label('How it was made'),
        if (!hasHowMade) Text(piece.checks.any((c) => c.key == 'howMade' && c.ok) ? 'Nothing on this piece. Another piece covers it, and one is enough.' : 'Nothing on this piece.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.text3)),
        _Files(files: piece.howMade),
        if (piece.processLink.isNotEmpty) ...[
          if (piece.howMade.isNotEmpty) const SizedBox(height: 10),
          LinkPreviewCard(url: piece.processLink, label: 'The link that shows how it was made'),
        ],
        const _Gap(),
        const _Label('Checks on this piece'),
        for (final c in piece.checks) _CheckRow(c: c),
      ]),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 18);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text.toUpperCase(), style: AppTextStyles.label));
}

class _CheckRow extends StatelessWidget {
  final SentCheck c;
  const _CheckRow({required this.c});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (c.state) {
      'ok' => (Icons.check_circle_rounded, AppColors.ok),
      'advice' => (Icons.info_outline_rounded, AppColors.warn),
      _ => (Icons.cancel_rounded, AppColors.bad),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
            Text(c.detail, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

// ── Files ──

/// A group of files: pictures as a grid of thumbnails you tap to open in the gallery, videos and documents as rows.
class _Files extends StatelessWidget {
  final List<SentFile> files;
  const _Files({required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final images = files.where((f) => f.kind == SentKind.image).toList();
    final others = files.where((f) => f.kind != SentKind.image).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (images.isNotEmpty)
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [for (final f in images) _Thumb(file: f, group: files)],
        ),
      if (images.isNotEmpty && others.isNotEmpty) const SizedBox(height: 10),
      for (final f in others) Padding(padding: const EdgeInsets.only(bottom: 8), child: _FileRow(file: f, group: files)),
    ]);
  }
}

class _Thumb extends StatelessWidget {
  final SentFile file;
  final List<SentFile> group;
  const _Thumb({required this.file, required this.group});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openSentFile(context, group, file),
      semanticLabel: 'Open picture ${file.name}',
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: file.url == null
              ? Container(color: AppColors.surface2, child: const Icon(Icons.image_not_supported_outlined, color: AppColors.text3))
              : Image.network(file.url!, fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, _, _) => Container(color: AppColors.surface2, child: const Icon(Icons.broken_image_outlined, color: AppColors.text3))),
        ),
        Positioned(right: 6, bottom: 6, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.zoom_out_map_rounded, size: 14, color: Colors.white))),
      ]),
    );
  }
}

class _FileRow extends StatelessWidget {
  final SentFile file;
  final List<SentFile> group;
  const _FileRow({required this.file, required this.group});

  @override
  Widget build(BuildContext context) {
    final video = file.kind == SentKind.video;
    final (icon, what) = switch (file.kind) {
      SentKind.video => (Icons.play_circle_fill_rounded, 'Video · tap to play'),
      SentKind.audio => (Icons.graphic_eq_rounded, 'Audio'),
      SentKind.pdf => (Icons.picture_as_pdf_outlined, 'PDF · opens in your PDF app'),
      _ => (Icons.insert_drive_file_outlined, 'File · opens in another app'),
    };
    return Pressable(
      onTap: () => openSentFile(context, group, file),
      semanticLabel: 'Open ${file.name}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        child: Row(children: [
          Container(
            width: video ? 64 : 44,
            height: 44,
            decoration: BoxDecoration(color: video ? Colors.black : AppColors.surface3, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: video ? 28 : 22, color: video ? Colors.white : AppColors.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              Text('$what · ${formatBytes(file.sizeBytes)}', style: AppTextStyles.hint),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
        ]),
      ),
    );
  }
}

// ── The walkthrough, with its real length ──

class _WalkthroughCard extends ConsumerWidget {
  final List<SentFile> files;
  const _WalkthroughCard({required this.files});

  /// 2 to 3 minutes was asked for. Shorter or longer is advice, not a failure: it is already sent.
  static (String, KdTone) _verdict(Duration d) {
    final s = d.inSeconds;
    if (s < 100) return ('Shorter than the 2 to 3 minutes we asked for. Reviewers may not have enough to go on.', KdTone.warn);
    if (s > 200) return ('Longer than the 3 minutes we asked for. Reviewers may stop watching before the end.', KdTone.warn);
    return ('Within the 2 to 3 minutes asked for.', KdTone.ok);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = files.isEmpty ? null : files.first;
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your walkthrough', style: AppTextStyles.title),
        const SizedBox(height: 4),
        Text('You explain the work on camera, in 2 to 3 minutes. It is the strongest proof that it is yours.', style: AppTextStyles.hint),
        const SizedBox(height: 12),
        if (f == null)
          Text('No walkthrough was sent.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))
        else ...[
          _FileRow(file: f, group: files),
          if (f.url != null) _Length(file: f),
        ],
      ]),
    );
  }
}

class _Length extends ConsumerWidget {
  final SentFile file;
  const _Length({required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(videoLengthProvider((name: file.name, url: file.url!)));
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: async.when(
        loading: () => Row(children: [const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Text('Reading its length…', style: AppTextStyles.hint)]),
        error: (_, _) => Text('Couldn\'t read its length.', style: AppTextStyles.hint),
        data: (d) {
          if (d == null) return Text('Couldn\'t read its length. Tap it to play and check.', style: AppTextStyles.hint);
          final (text, tone) = _WalkthroughCard._verdict(d);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(tone == KdTone.ok ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 18, color: tone == KdTone.ok ? AppColors.ok : AppColors.warn),
            const SizedBox(width: 10),
            Expanded(child: Text('${clock(d)} long. $text', style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2, height: 1.4))),
          ]);
        },
      ),
    );
  }
}

// ── The declaration ──

class _Declaration extends StatelessWidget {
  final SentWork w;
  const _Declaration({required this.w});

  @override
  Widget build(BuildContext context) {
    Widget line(String q, String a, {bool good = true}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [Expanded(child: Text(q, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text2))), Text(a, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: good ? AppColors.text : AppColors.warn))]),
    );
    return KdCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your declaration', style: AppTextStyles.title),
        const SizedBox(height: 10),
        line('The work is my own', w.ownWork ? 'Yes' : 'No', good: w.ownWork),
        line('I used AI', w.aiUsed ? 'Yes' : 'No'),
        if (w.aiUsed && (w.aiNote ?? '').isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)), child: Text('"${w.aiNote}"', style: AppTextStyles.bodySmall)),
      ]),
    );
  }
}
