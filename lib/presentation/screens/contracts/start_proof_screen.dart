import '../../../core/constants/glossary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/debug_log.dart';
import '../../../core/formatting/currency.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/contract_extras.dart';
import '../../../data/models/job.dart';
import '../../providers/contract_extras_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/about_amount_text.dart';
import '../../widgets/kit/evidence_viewer.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/reason_sheet.dart';
import '../../widgets/kit/status_pill.dart';
import '../skills/file_section.dart' show iconForType;

/// The start proof (PRD §4.2): after a job is paid the talent shows they have started, in the skill's fixed format.
/// The client has 24 hours to accept or raise a point, and silence accepts. Accepting pays the talent the first 20%
/// at once; the rest is paid when the delivery is approved. A point the client raises is checked by a person
/// against the format, never for taste.
class StartProofScreen extends ConsumerWidget {
  final String jobId;
  final bool forClient;
  const StartProofScreen({super.key, required this.jobId, required this.forClient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(startProofProvider(jobId));
    final job = ref.watch(jobsProvider).valueOrNull?.where((j) => j.id == jobId).firstOrNull;
    return Scaffold(
      body: async.when(
        loading: () => ListView(
          padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 70, AppDimensions.gutter, 24),
          children: const [Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
        ),
        error: (_, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
            Expanded(child: Center(child: ErrorState(message: 'Couldn\'t load the start proof. Check your connection and try again.', onRetry: () async => ref.invalidate(startProofProvider(jobId))))),
          ]),
        ),
        data: (proof) => LiveClock(builder: (_) => _Body(jobId: jobId, job: job, proof: proof, forClient: forClient)),
      ),
    );
  }
}

StatusPill _pill(StartProof p) => switch (p.status) {
  null => const StatusPill('To send', tone: KdTone.brand),
  'submitted' => const StatusPill('With the client', tone: KdTone.warn, pulse: true),
  'objected' => const StatusPill('Being checked', tone: KdTone.warn, pulse: true),
  'accepted' => const StatusPill('Accepted', tone: KdTone.ok, icon: Icons.check_rounded),
  _ => const StatusPill('Send again', tone: KdTone.warn),
};

class _Body extends ConsumerWidget {
  final String jobId;
  final Job? job;
  final StartProof proof;
  final bool forClient;
  const _Body({required this.jobId, required this.job, required this.proof, required this.forClient});

  String get _money => formatMoney(proof.upfrontAmount, proof.currency);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talentName = 'the talent';
    final clientName = job?.clientName ?? 'the client';
    final cards = <Widget>[
      ..._stateCards(clientName, talentName),
      for (final f in proof.fields)
        if (proof.editable && !forClient)
          _FieldEditor(jobId: jobId, field: f, uploadsAvailable: proof.uploadsAvailable)
        else
          _FieldView(field: f),
    ];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => ref.invalidate(startProofProvider(jobId)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 220),
            children: [
              ContractHeader(title: 'Start proof', sub: '${job?.title ?? 'Your job'} · first 20% is $_money', pill: _pill(proof), tip: Glossary.startProof),
              for (var i = 0; i < cards.length; i++)
                Padding(padding: const EdgeInsets.only(top: 12), child: RiseIn(delay: Duration(milliseconds: 50 * i), child: cards[i])),
            ],
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: ActionBar(children: _actions(context, ref))),
      ],
    );
  }

  List<Widget> _stateCards(String clientName, String talentName) {
    final due = proof.dueAt;
    switch (proof.status) {
      case null:
        return [
          NoticeCard(
            tone: KdTone.brand,
            icon: Icons.flag_outlined,
            title: forClient ? 'The talent is getting started' : 'Show $clientName you\'ve started',
            body: forClient
                ? 'Before the first 20% is paid, the talent sends a start proof in the format this skill asks for. You\'ll have 24 hours to look at it.'
                : 'Add each part below, then send it. $clientName has 24 hours to accept it or raise a point, and if they say nothing it counts as accepted. '
                    'When it\'s accepted, $_money (20%) is paid to your bank account at once, and the rest when they approve your delivery.',
            extra: forClient ? null : AboutAmountText(amount: proof.upfrontAmount, currency: proof.currency),
          ),
        ];
      case 'redo':
        return [
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.replay_rounded,
            title: forClient ? 'Sent back to the talent' : 'Your start proof needs another go',
            body: forClient
                ? 'A person checked it against the format and agreed with your point. The talent will send it again, and you\'ll have another 24 hours.'
                : 'A person at King Domain checked it against the format and agreed with the client\'s point. Add what is missing and send it again.',
            quote: proof.objection?.note,
            footnote: proof.objection?.label,
          ),
        ];
      case 'submitted':
        final left = due == null ? null : timeLeft(due);
        return [
          NoticeCard(
            tone: forClient ? KdTone.warn : KdTone.brand,
            icon: Icons.schedule_rounded,
            title: forClient ? 'Look at the start proof' : 'With $clientName',
            body: forClient
                ? 'Accepting pays the talent $_money (20%) now. If it isn\'t what the format asks for, raise a point and a person will check it. '
                    'Quality and taste aren\'t grounds: this only shows they\'ve started.'
                : '$clientName can accept it or raise a point. If they say nothing, it counts as accepted.',
            waiting: due == null ? null : (left == null ? 'The 24 hours are up: it is being accepted' : '$left left'),
            footnote: due == null ? null : 'Decide by ${formatDeadline(due)}',
          ),
        ];
      case 'objected':
        return [
          NoticeCard(
            tone: KdTone.warn,
            icon: Icons.fact_check_outlined,
            title: 'A person is checking it',
            body: forClient
                ? 'You raised a point. A King Domain person will check the start proof against the format, usually within the day, and we\'ll tell you both.'
                : '$clientName raised a point. A King Domain person is checking your start proof against the format, usually within the day. You\'ll hear back.',
            quote: proof.objection?.note,
            footnote: proof.objection?.label,
          ),
        ];
      default:
        return [
          NoticeCard(
            tone: KdTone.ok,
            icon: Icons.check_circle_outline_rounded,
            title: forClient ? 'Accepted. $_money went to the talent' : 'Accepted. $_money is on its way',
            body: forClient
                ? 'The other 80% is paid when you approve the delivery.'
                : 'Sent to your payout account. Transfers can take a little while to show. You can deliver the work whenever it is ready.',
          ),
        ];
    }
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    final actions = ref.read(contractExtrasActionsProvider);
    if (forClient && proof.status == 'submitted') {
      return [
        KdButton(
          label: 'Accept · pay $_money',
          busyLabel: 'Paying',
          icon: Icons.check_rounded,
          onPressed: () async {
            try {
              await actions.acceptProof(jobId);
            } on ApiException catch (e) {
              if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
              throw const ShownError();
            }
            if (context.mounted) KdToast.show(context, 'Accepted. $_money sent to the talent');
          },
        ),
        KdButton.secondary(label: 'Raise a point', onPressed: () => _object(context, ref)),
      ];
    }
    if (!forClient && proof.editable) {
      return [
        if (!proof.readyToSend && proof.missing.isNotEmpty)
          Text('Still to add: ${proof.missing.join('; ')}.', textAlign: TextAlign.center, style: AppTextStyles.hint),
        KdButton(
          label: proof.status == 'redo' ? 'Send it again' : 'Send the start proof',
          busyLabel: 'Sending',
          icon: Icons.send_rounded,
          onPressed: !proof.readyToSend
              ? null
              : () async {
                  try {
                    await actions.submitProof(jobId);
                  } on ApiException catch (e) {
                    if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
                    throw const ShownError();
                  }
                  if (context.mounted) KdToast.show(context, 'Sent. The client has 24 hours');
                },
        ),
      ];
    }
    return const [];
  }

  Future<void> _object(BuildContext context, WidgetRef ref) async {
    final choice = await showReasonSheet(
      context,
      title: 'What is wrong with it?',
      lead: 'Pick what applies. A person will check the start proof against the format. Taste isn\'t a reason: the work itself is judged when it is delivered.',
      codes: [for (final r in proof.objectionReasons) ReasonCode(code: r.code, label: r.label)],
      confirmLabel: 'Send to be checked',
    );
    if (choice == null || !context.mounted) return;
    try {
      await ref.read(contractExtrasActionsProvider).objectToProof(jobId, reasonCode: choice.code, note: choice.note);
      kdLog('start-proof', 'objected job=$jobId reason=${choice.code}');
      if (context.mounted) KdToast.show(context, 'Sent. A person will check it', kind: ToastKind.info);
    } on ApiException catch (e) {
      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }
}

/// What a part holds, shown read-only (the client, or the talent once sent).
class _FieldView extends StatelessWidget {
  final ProofField field;
  const _FieldView({required this.field});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(field.label, style: AppTextStyles.title)),
        if (field.items.isEmpty)
          KdCard(child: Text('Nothing was added.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.text2)))
        else
          EvidenceViewer(items: [
            for (final i in field.items)
              EvidenceItem(
                kind: switch (field.kind) {
                  'image' => EvidenceKind.image,
                  'video' => EvidenceKind.video,
                  'link' => EvidenceKind.link,
                  'text' => EvidenceKind.text,
                  _ => (i.contentType ?? '').startsWith('image/') ? EvidenceKind.image : (i.contentType ?? '').startsWith('video/') ? EvidenceKind.video : EvidenceKind.file,
                },
                label: i.name ?? field.label,
                text: i.text,
                url: field.kind == 'link' ? i.text : i.url,
                sizeBytes: i.sizeBytes,
              ),
          ]),
      ],
    );
  }
}

/// One part the talent fills in: typed, a link, or files that go straight to storage.
class _FieldEditor extends ConsumerStatefulWidget {
  final String jobId;
  final ProofField field;
  final bool uploadsAvailable;
  const _FieldEditor({required this.jobId, required this.field, required this.uploadsAvailable});

  @override
  ConsumerState<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends ConsumerState<_FieldEditor> {
  final Map<String, double> _sending = {};
  String? _problem;

  static final _program = RegExp(r'\.(apk|exe|bat|msi|scr|cmd|com|jar|dmg|sh|ps1|vbs)$', caseSensitive: false);

  String? _check(PickedFile f) {
    final kind = widget.field.kind;
    if (f.size <= 0) return '${f.name} is empty.';
    if (_program.hasMatch(f.name)) return '${f.name}: programs and installers can\'t be sent here.';
    if (kind == 'image' && !f.contentType.startsWith('image/')) return '${f.name}: this part takes a picture.';
    if (kind == 'video' && !f.contentType.startsWith('video/')) return '${f.name}: this part takes a video.';
    final max = kind == 'video' ? 500 * 1024 * 1024 : 100 * 1024 * 1024;
    if (f.size > max) return '${f.name} is ${formatBytes(f.size)}. The limit here is ${formatBytes(max)}.';
    return null;
  }

  Future<void> _upload(List<PickedFile> picked) async {
    final actions = ref.read(contractExtrasActionsProvider);
    final problems = <String>[];
    var room = widget.field.max - widget.field.items.length;
    for (final f in picked) {
      final bad = _check(f);
      kdLog('start-proof', '${widget.field.key}: picked ${f.name} ${f.size} bytes ${f.contentType} -> ${bad ?? 'ok'}');
      if (bad != null) {
        problems.add(bad);
        continue;
      }
      if (room <= 0) {
        problems.add('${widget.field.label}: at most ${widget.field.max}.');
        break;
      }
      setState(() => _sending[f.name] = 0);
      try {
        await actions.addProofFile(widget.jobId, widget.field.key, f, onProgress: (v) {
          if (mounted) setState(() => _sending[f.name] = v);
        });
        room--;
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
    final List<PickedFile> picked;
    switch (widget.field.kind) {
      case 'image':
        picked = await gateway.pickMedia();
      case 'video':
        final v = await gateway.pickVideo();
        picked = v == null ? const [] : [v];
      default:
        final choice = await showKdSheet<String>(
          context,
          builder: (sheet) => KdSheetBody(
            title: 'Add to ${widget.field.label.toLowerCase()}',
            lead: 'Needs ${widget.field.countWords}.',
            children: [
              const SizedBox(height: 12),
              KdButton(label: 'Photos or videos', icon: Icons.photo_library_outlined, onPressed: () => Navigator.of(sheet).pop('media')),
              const SizedBox(height: 8),
              KdButton.secondary(label: 'PDFs, documents and other files', onPressed: () => Navigator.of(sheet).pop('files')),
            ],
          ),
        );
        if (choice == null) return;
        picked = choice == 'media' ? await gateway.pickMedia() : await gateway.pickDocuments();
    }
    if (picked.isEmpty) return;
    await _upload(picked);
  }

  Future<void> _write() async {
    final existing = widget.field.items.firstOrNull?.text ?? '';
    final text = await showKdSheet<String>(
      context,
      builder: (sheet) => _TextSheet(field: widget.field, initial: existing),
    );
    if (text == null) return;
    try {
      await ref.read(contractExtrasActionsProvider).saveText(widget.jobId, widget.field.key, text);
      if (mounted) setState(() => _problem = null);
    } on ApiException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  Future<void> _remove(ProofItem i) async {
    try {
      await ref.read(contractExtrasActionsProvider).removeItem(widget.jobId, i.id);
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final needsStorage = f.isFile && !widget.uploadsAvailable;
    return KdCard(
      tone: f.done ? KdTone.ok : KdTone.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(f.label, style: AppTextStyles.title)),
            if (f.done) const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppColors.ok),
          ]),
          const SizedBox(height: 4),
          Text(switch (f.kind) {
            'text' => 'Write it out. At least 20 characters.',
            'link' => 'A link that starts with http:// or https://.',
            'image' => 'Needs ${f.countWords} picture${f.max == 1 ? '' : 's'}.',
            'video' => 'Needs ${f.countWords} video.',
            _ => 'Needs ${f.countWords} file${f.max == 1 ? '' : 's'}. Pictures, videos, PDFs and documents.',
          }, style: AppTextStyles.hint),
          for (final i in f.items) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(f.isTyped ? (f.kind == 'link' ? Icons.link_rounded : Icons.notes_rounded) : iconForType(i.contentType ?? ''), size: 20, color: AppColors.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.text ?? i.name ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium),
                  if (i.sizeBytes != null) Text(formatBytes(i.sizeBytes!), style: AppTextStyles.hint),
                ]),
              ),
              if (!f.isTyped)
                Pressable(
                  onTap: () => _remove(i),
                  semanticLabel: 'Remove ${i.name}',
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
          if (needsStorage) ...[
            const SizedBox(height: 10),
            Text('Sending files isn\'t available right now. Try again later.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warn)),
          ] else if (f.isTyped) ...[
            const SizedBox(height: 12),
            KdButton.secondary(label: f.items.isEmpty ? (f.kind == 'link' ? 'Add the link' : 'Write it') : 'Change it', icon: f.items.isEmpty ? Icons.add_rounded : Icons.edit_outlined, height: AppDimensions.buttonHeightSm, onPressed: _write),
          ] else if (!f.full) ...[
            const SizedBox(height: 12),
            KdButton.secondary(label: f.items.isEmpty ? 'Add' : 'Add more', icon: Icons.add_rounded, height: AppDimensions.buttonHeightSm, onPressed: _sending.isNotEmpty ? null : _add),
          ],
        ],
      ),
    );
  }
}

class _TextSheet extends StatefulWidget {
  final ProofField field;
  final String initial;
  const _TextSheet({required this.field, required this.initial});

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _c = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = _c.text.trim();
    if (widget.field.kind == 'link' && !RegExp(r'^https?://\S+\.\S+$', caseSensitive: false).hasMatch(v)) {
      setState(() => _error = 'The link must start with http:// or https://.');
      return;
    }
    if (widget.field.kind == 'text' && v.length < 20) {
      setState(() => _error = 'Write at least 20 characters.');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: widget.field.label,
      lead: widget.field.kind == 'link' ? 'Paste the link. The client can open it.' : 'Write it so the client can follow it.',
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          autofocus: true,
          maxLines: widget.field.kind == 'link' ? 1 : 6,
          keyboardType: widget.field.kind == 'link' ? TextInputType.url : TextInputType.multiline,
          decoration: InputDecoration(hintText: widget.field.kind == 'link' ? 'https://' : null, errorText: _error),
        ),
        const SizedBox(height: 14),
        KdButton(label: 'Save', onPressed: _save),
        const SizedBox(height: 8),
        KdButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
