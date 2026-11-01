import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/debug_log.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/contract_extras.dart';
import '../../providers/contract_extras_provider.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/evidence_viewer.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';

/// Drafts: work in progress the talent shows, dated, without handing it in. Sharing one starts no clock and asks
/// nothing of the client, and each is kept as evidence the work was being made.
class DraftsScreen extends ConsumerWidget {
  final String jobId;
  final String jobTitle;
  final bool forClient;
  /// The talent can share only while the job is being worked on.
  final bool canShare;
  const DraftsScreen({super.key, required this.jobId, required this.jobTitle, required this.forClient, required this.canShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(draftsProvider(jobId));
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: ErrorState(message: 'Couldn\'t load the drafts. Check your connection and try again.', onRetry: () async => ref.invalidate(draftsProvider(jobId))))),
          ]),
        ),
        data: (list) => Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(draftsProvider(jobId)),
              child: ListView(
                padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 200),
                children: [
                  ContractHeader(title: 'Drafts', sub: jobTitle, pill: StatusPill('${list.drafts.length} shared', tone: KdTone.brand)),
                  const SizedBox(height: 12),
                  if (list.drafts.isEmpty)
                    EmptyState(
                      icon: Icons.draw_outlined,
                      title: forClient ? 'No drafts yet' : 'Nothing shared yet',
                      body: forClient
                          ? 'When the talent shares work in progress it shows up here. You don\'t need to do anything with it: it is only a look at how it is going.'
                          : 'Share work in progress so the client can see it taking shape. It doesn\'t hand anything in or start any clock, and it is kept as a record that you were making it.',
                    ),
                  for (var i = 0; i < list.drafts.length; i++)
                    Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 50 * i), child: _DraftCard(draft: list.drafts[i]))),
                ],
              ),
            ),
            if (!forClient && canShare)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ActionBar(children: [
                  if (!list.uploadsAvailable)
                    Text('Sharing files isn\'t available right now. Try again later.', textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: AppColors.warn)),
                  KdButton(label: 'Share a draft', icon: Icons.upload_rounded, onPressed: list.uploadsAvailable ? () => _share(context, ref) : null),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    await showKdSheet(context, builder: (_) => _ShareSheet(jobId: jobId));
  }
}

class _DraftCard extends StatelessWidget {
  final DraftShare draft;
  const _DraftCard({required this.draft});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Shared ${formatDeadline(draft.createdAt)}${draft.note.isEmpty ? '' : ': ${draft.note}'}', style: AppTextStyles.title),
        ),
        EvidenceViewer(items: [
          for (final f in draft.files)
            EvidenceItem(
              kind: f.contentType.startsWith('image/') ? EvidenceKind.image : f.contentType.startsWith('video/') ? EvidenceKind.video : EvidenceKind.file,
              label: f.name,
              url: f.url,
              sizeBytes: f.sizeBytes,
            ),
        ]),
      ],
    );
  }
}

class _ShareSheet extends ConsumerStatefulWidget {
  final String jobId;
  const _ShareSheet({required this.jobId});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _note = TextEditingController();
  final List<PickedFile> _files = [];
  final Map<String, double> _sending = {};
  String? _error;
  bool _busy = false;

  static final _program = RegExp(r'\.(apk|exe|bat|msi|scr|cmd|com|jar|dmg|sh|ps1|vbs)$', caseSensitive: false);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final gateway = ref.read(fileGatewayProvider);
    final picked = [...await gateway.pickMedia()];
    if (picked.isEmpty) picked.addAll(await gateway.pickDocuments());
    final problems = <String>[];
    for (final f in picked) {
      if (_program.hasMatch(f.name)) {
        problems.add('${f.name}: programs and installers can\'t be sent here.');
      } else if (f.size <= 0 || f.size > 500 * 1024 * 1024) {
        problems.add('${f.name}: files must be under 500 MB.');
      } else if (_files.length >= 10) {
        problems.add('Share up to 10 files at a time.');
        break;
      } else {
        _files.add(f);
      }
    }
    if (mounted) setState(() => _error = problems.isEmpty ? null : problems.join('\n'));
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(contractExtrasActionsProvider).shareDraft(widget.jobId, note: _note.text.trim(), files: _files, onProgress: (n, v) {
        if (mounted) setState(() => _sending[n] = v);
      });
      kdLog('drafts', 'shared ${_files.length} file(s) for job=${widget.jobId}');
      if (!mounted) return;
      Navigator.of(context).pop();
      KdToast.show(context, 'Shared. The client can see it now');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: 'Share a draft',
      lead: 'Show the work as it stands. This doesn\'t hand it in or start the client\'s review time.',
      children: [
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 600, maxLines: 2, enabled: !_busy, decoration: const InputDecoration(hintText: 'A line about what this shows (optional)')),
        for (final f in _files)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.text2),
              const SizedBox(width: 8),
              Expanded(child: Text('${f.name} · ${formatBytes(f.size)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall)),
              if (_sending[f.name] != null) SizedBox(width: 60, child: LinearProgressIndicator(value: _sending[f.name] == 0 ? null : _sending[f.name], minHeight: 4, color: AppColors.primary, backgroundColor: AppColors.surface3)),
              if (!_busy) IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _files.remove(f)), icon: const Icon(Icons.close_rounded, size: 18)),
            ]),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad))),
        const SizedBox(height: 10),
        KdButton.secondary(label: _files.isEmpty ? 'Choose files' : 'Add more files', icon: Icons.add_rounded, onPressed: _busy ? null : _pick),
        const SizedBox(height: 8),
        KdButton(label: 'Share ${_files.length} file${_files.length == 1 ? '' : 's'}', busyLabel: 'Sharing', onPressed: _files.isEmpty || _busy ? null : _send),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: _busy ? null : () => Navigator.of(context).pop()),
      ],
    );
  }
}
