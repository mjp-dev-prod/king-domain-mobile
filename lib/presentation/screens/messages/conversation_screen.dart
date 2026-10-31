import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../../data/models/messaging.dart';
import '../../providers/messaging_provider.dart';
import '../../providers/skill_submissions_provider.dart';
import '../../widgets/contract/contract_parts.dart' show NoticeCard;
import '../../widgets/kit/evidence_viewer.dart' show formatBytes;
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/pressable.dart';

/// One conversation (PRD §4.7): messages, the job's own events as cards, "what we agreed", attachments, report and
/// block. New messages arrive by asking every few seconds while the screen is open, and by push when it is not.
class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ConversationScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _text = TextEditingController();
  late final ConversationNotifier _notifier = ref.read(conversationProvider(widget.conversationId).notifier);
  ChatMessage? _editing;
  String? _sendError;
  double? _uploading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifier.startPolling());
  }

  @override
  void dispose() {
    _notifier.stopPolling();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    final editing = _editing;
    setState(() => _sendError = null);
    try {
      if (editing != null) {
        await _notifier.edit(editing, body);
        setState(() => _editing = null);
      } else {
        _text.clear();
        await _notifier.send(body);
      }
      if (editing != null) _text.clear();
    } on ApiException catch (e) {
      // Offline: it stays in the list as "not sent" with Retry. Anything else is said once, here, and the text is kept to change.
      if (e.status == 0) return;
      if (editing == null) _text.text = body;
      setState(() => _sendError = e.message);
    }
  }

  Future<void> _attach(ConversationView v) async {
    if (!v.uploadsAvailable) {
      KdToast.show(context, "Sending files isn't available right now. Try again later.", kind: ToastKind.error);
      return;
    }
    final choice = await showKdSheet<String>(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Send',
        lead: 'Photos and files go straight to private storage. Nothing is saved to your phone or the other person\'s until they tap it.',
        children: [
          const SizedBox(height: 12),
          KdButton(label: 'A photo', icon: Icons.photo_outlined, onPressed: () => Navigator.of(sheet).pop('photo')),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'A file or audio', icon: Icons.attach_file_rounded, onPressed: () => Navigator.of(sheet).pop('file')),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'What we agreed', icon: Icons.handshake_outlined, onPressed: () => Navigator.of(sheet).pop('agreement')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'agreement') {
      await _writeAgreement();
      return;
    }
    final gateway = ref.read(fileGatewayProvider);
    final picked = choice == 'photo' ? await gateway.pickMedia() : await gateway.pickDocuments();
    for (final f in picked) {
      if (!mounted) return;
      final kind = f.contentType.startsWith('image/') ? 'image' : 'file';
      setState(() => _uploading = 0);
      try {
        await _notifier.sendAttachment(kind: kind, file: f, onProgress: (p) => mounted ? setState(() => _uploading = p) : null);
      } on ApiException catch (e) {
        if (mounted) KdToast.show(context, '${f.name}: ${e.message}', kind: ToastKind.error);
      } finally {
        if (mounted) setState(() => _uploading = null);
      }
    }
  }

  Future<void> _writeAgreement() async {
    final c = TextEditingController();
    final done = await showKdSheet<bool>(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Write down what you agreed',
        lead: 'What, for how much, and by when. It only counts once the other person confirms it, and if there is ever a disagreement, what is written here is what counts.',
        children: [
          const SizedBox(height: 12),
          KdTextField(controller: c, label: 'e.g. Three reels, ₦25,000, delivered by Friday 21 Nov', maxLines: 4),
          const SizedBox(height: 14),
          KdButton(
            label: 'Send for confirmation',
            busyLabel: 'Sending',
            onPressed: () async {
              try {
                await _notifier.sendAgreement(c.text.trim());
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              if (sheet.mounted) Navigator.of(sheet).pop(true);
            },
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 500), c.dispose);
    if (done == true && mounted) KdToast.show(context, 'Sent. It counts once they confirm.');
  }

  Future<void> _open(String? url) async {
    if (url == null) return;
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) KdToast.show(context, "Couldn't open it. Try again.", kind: ToastKind.error);
  }

  void _longPress(ConversationView v, ChatMessage m) {
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Message',
        children: [
          const SizedBox(height: 12),
          if (m.canEditNow())
            KdButton(
              label: 'Change it',
              icon: Icons.edit_outlined,
              onPressed: () {
                Navigator.of(sheet).pop();
                setState(() => _editing = m);
                _text.text = m.body;
              },
            ),
          if (m.canEditNow()) const SizedBox(height: 8),
          if (!m.mine && m.local == null) KdButton.secondary(label: 'Report this message', icon: Icons.flag_outlined, onPressed: () { Navigator.of(sheet).pop(); _report(v, m); }),
          if (m.mine && !m.canEditNow()) Text('Messages stay as sent after 15 minutes, so they can be relied on if there is ever a dispute.', style: AppTextStyles.hint),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Close', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  Future<void> _report(ConversationView v, ChatMessage m) async {
    String? code;
    final note = TextEditingController();
    final sent = await showKdSheet<bool>(
      context,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheet) => KdSheetBody(
          title: 'Report this message',
          lead: 'The King Domain team reads it. The other person is not told who reported.',
          children: [
            const SizedBox(height: 10),
            for (final r in v.reasons)
              Pressable(
                onTap: () => setSheet(() => code = r.code),
                semanticLabel: r.label,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [Icon(code == r.code ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: code == r.code ? AppColors.primaryText : AppColors.text3), const SizedBox(width: 10), Expanded(child: Text(r.label, style: AppTextStyles.bodyMedium))]),
                ),
              ),
            const SizedBox(height: 8),
            KdTextField(controller: note, label: 'Anything we should know (optional)', maxLines: 3),
            const SizedBox(height: 14),
            KdButton(
              label: 'Send report',
              busyLabel: 'Sending',
              onPressed: () async {
                if (code == null) {
                  KdToast.show(sheet, 'Choose what is wrong.', kind: ToastKind.error);
                  throw const ShownError();
                }
                try {
                  await _notifier.report(m, reasonCode: code!, note: note.text);
                } on ApiException catch (e) {
                  if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                  throw const ShownError();
                }
                if (sheet.mounted) Navigator.of(sheet).pop(true);
              },
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 500), note.dispose);
    if (sent == true && mounted) KdToast.show(context, 'Reported. Thank you: the team will look at it.');
  }

  Future<void> _blockMenu(ConversationView v) async {
    await showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: v.otherName,
        children: [
          const SizedBox(height: 12),
          if (!v.canBlock)
            const NoticeCard(
              tone: KdTone.plain,
              icon: Icons.lock_outline_rounded,
              title: "Blocking isn't available now",
              body: 'You have a job running together, so the conversation has to stay open. You can report any message from them instead: press and hold it.',
            )
          else
            KdButton(
              label: v.blocked ? 'Unblock ${v.otherName.split(' ').first}' : 'Block ${v.otherName.split(' ').first}',
              variant: v.blocked ? KdButtonVariant.primary : KdButtonVariant.danger,
              busyLabel: 'Saving',
              onPressed: () async {
                try {
                  await _notifier.setBlocked(v.otherId, blocked: !v.blocked);
                } on ApiException catch (e) {
                  if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                  throw const ShownError();
                }
                if (sheet.mounted) Navigator.of(sheet).pop();
              },
            ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Close', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationProvider(widget.conversationId));
    final dataSaver = ref.watch(dataSaverProvider);
    return Scaffold(
      body: async.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't open this conversation. Check your connection and try again.", onRetry: () async => ref.invalidate(conversationProvider(widget.conversationId)))),
        data: (state) {
          final v = state.view;
          final items = <_Item>[
            for (final m in state.all) _Item(m.createdAt, message: m),
            for (final e in v.events) _Item(e.at, event: e),
          ]..sort((a, b) => a.at.compareTo(b.at));
          return Column(
            children: [
              _Header(view: v, onMenu: () => _blockMenu(v)),
              if (!v.awarded)
                Container(
                  width: double.infinity,
                  color: AppColors.surface1,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.gutter, vertical: 8),
                  child: Text('Until a job is awarded, keep everything in King Domain: no phone numbers, links or payment talk. It protects you both.', style: AppTextStyles.hint),
                ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Say hello', body: 'Introduce the job and what you need. Keep it inside King Domain.'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 12, AppDimensions.gutter, 12),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final it = items[items.length - 1 - i];
                          final w = it.event != null
                              ? _EventCard(event: it.event!)
                              : _Bubble(
                                  message: it.message!,
                                  dataSaver: dataSaver,
                                  onOpen: _open,
                                  onLongPress: () => _longPress(v, it.message!),
                                  onRetry: () => _notifier.retry(it.message!),
                                  onConfirm: () async {
                                    try {
                                      await _notifier.confirmAgreement(it.message!);
                                    } on ApiException catch (e) {
                                      if (context.mounted) KdToast.show(context, e.message, kind: ToastKind.error);
                                    }
                                  },
                                  onFixHeld: () {
                                    setState(() => _editing = null);
                                    _text.text = it.message!.body;
                                  },
                                );
                          return Padding(padding: const EdgeInsets.only(bottom: 8), child: w);
                        },
                      ),
              ),
              if (_uploading != null) LinearProgressIndicator(value: _uploading == 0 ? null : _uploading, minHeight: 3, backgroundColor: AppColors.surface3, color: AppColors.primary),
              if (v.blocked)
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.gutter),
                  child: NoticeCard(tone: KdTone.plain, icon: Icons.block_rounded, title: 'This conversation is blocked', body: 'Neither of you can send messages while it is blocked.', actions: [KdButton(label: 'Unblock', variant: KdButtonVariant.soft, height: AppDimensions.buttonHeightSm, onPressed: () => _blockMenu(v))]),
                )
              else
                _Composer(
                  controller: _text,
                  editing: _editing != null,
                  error: _sendError,
                  onSend: _send,
                  onAttach: () => _attach(v),
                  onCancelEdit: () => setState(() {
                    _editing = null;
                    _text.clear();
                  }),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Item {
  final DateTime at;
  final ChatMessage? message;
  final ChatEvent? event;
  _Item(this.at, {this.message, this.event});
}

class _Header extends StatelessWidget {
  final ConversationView view;
  final VoidCallback onMenu;
  const _Header({required this.view, required this.onMenu});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface1,
    padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 4, 8, 8),
    child: Row(
      children: [
        IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
        UserAvatar(name: view.otherName, photoUrl: view.otherPhotoUrl, size: 38),
        const SizedBox(width: 10),
        Expanded(child: Text(view.otherName, style: AppTextStyles.title, overflow: TextOverflow.ellipsis)),
        IconButton(tooltip: 'More', icon: const Icon(Icons.more_horiz_rounded), onPressed: onMenu),
      ],
    ),
  );
}

/// A job event between the messages: awarded, funded, delivered, approved (the contract room, PRD §4.7).
class _EventCard extends StatelessWidget {
  final ChatEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(event.text, textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        Text('${event.jobTitle} · ${formatAgo(event.at)}', textAlign: TextAlign.center, style: AppTextStyles.hint),
      ]),
    ),
  );
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool dataSaver;
  final Future<void> Function(String? url) onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onRetry;
  final VoidCallback onConfirm;
  final VoidCallback onFixHeld;
  const _Bubble({required this.message, required this.dataSaver, required this.onOpen, required this.onLongPress, required this.onRetry, required this.onConfirm, required this.onFixHeld});

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.kind == MessageKind.agreement) return _Agreement(message: m, onConfirm: onConfirm, onLongPress: onLongPress);
    final mine = m.mine;
    final maxWidth = MediaQuery.sizeOf(context).width * .78;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: m.held ? AppColors.warnSoft : (mine ? AppColors.primarySoft : AppColors.surface1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _content(context, m),
                const SizedBox(height: 4),
                if (m.held) ...[
                  Text(m.heldWhy ?? 'Not sent.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warn)),
                  const SizedBox(height: 6),
                  Pressable(onTap: onFixHeld, semanticLabel: 'Change this message', child: Text('Change it', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText, fontWeight: FontWeight.w700))),
                ] else if (m.local == LocalState.sending)
                  Text('Sending…', style: AppTextStyles.hint)
                else if (m.local == LocalState.failed)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Not sent. ', style: AppTextStyles.hint.copyWith(color: AppColors.bad)),
                    Pressable(onTap: onRetry, semanticLabel: 'Retry sending', child: Text('Retry', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText, fontWeight: FontWeight.w700))),
                  ])
                else
                  Text('${formatAgo(m.createdAt)}${m.edited ? ' · edited' : ''}', style: AppTextStyles.hint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ChatMessage m) {
    final a = m.attachment;
    switch (m.kind) {
      case MessageKind.image:
        if (a == null) return const Text('Photo');
        // Data saver: nothing loads until it is tapped, and the size shows first.
        if (dataSaver || a.url == null) {
          return _Tile(icon: Icons.photo_outlined, title: 'Photo', sub: formatBytes(a.sizeBytes), onTap: a.url == null ? null : () => onOpen(a.url));
        }
        return Pressable(
          onTap: () => onOpen(a.url),
          semanticLabel: 'Open photo',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Image.network(a.url!, width: 220, fit: BoxFit.cover, errorBuilder: (_, _, _) => _Tile(icon: Icons.broken_image_outlined, title: 'Photo', sub: 'Tap to open', onTap: () => onOpen(a.url)), loadingBuilder: (c, child, p) => p == null ? child : const SizedBox(width: 220, height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))),
          ),
        );
      case MessageKind.voice:
        final s = a?.durationSec ?? 0;
        return _Tile(icon: Icons.mic_none_rounded, title: 'Voice note ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}', sub: a == null ? '' : formatBytes(a.sizeBytes), onTap: a?.url == null ? null : () => onOpen(a!.url));
      case MessageKind.file:
        return _Tile(icon: _fileIcon(a?.contentType), title: a?.name ?? 'File', sub: a == null ? '' : formatBytes(a.sizeBytes), onTap: a?.url == null ? null : () => onOpen(a!.url));
      case MessageKind.text:
      case MessageKind.agreement:
        return Text(m.body, style: AppTextStyles.bodyMedium);
    }
  }

  IconData _fileIcon(String? type) => (type ?? '').startsWith('audio/') ? Icons.audiotrack_outlined : (type ?? '').startsWith('video/') ? Icons.videocam_outlined : Icons.insert_drive_file_outlined;
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap ?? () {},
    semanticLabel: '$title, $sub',
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppColors.text2),
      const SizedBox(width: 10),
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis), if (sub.isNotEmpty) Text('$sub · tap to open', style: AppTextStyles.hint)])),
    ]),
  );
}

/// "What we agreed": counts only once both people have confirmed it.
class _Agreement extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onConfirm;
  final VoidCallback onLongPress;
  const _Agreement({required this.message, required this.onConfirm, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final a = message.agreement!;
    return GestureDetector(
      onLongPress: onLongPress,
      child: NoticeCard(
        tone: a.agreed ? KdTone.ok : KdTone.warn,
        icon: a.agreed ? Icons.handshake_rounded : Icons.handshake_outlined,
        title: a.agreed ? 'Agreed by both of you' : 'What we agreed',
        quote: message.body,
        body: a.agreed ? 'Written down and confirmed. If there is ever a disagreement, this is what counts.' : (a.confirmedByMe ? 'Waiting for them to confirm. It only counts once they do.' : 'Read it carefully. It only counts once you confirm.'),
        actions: a.confirmedByMe ? const [] : [KdButton(label: 'Confirm this is right', busyLabel: 'Confirming', height: AppDimensions.buttonHeightSm, onPressed: () async => onConfirm())],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool editing;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onCancelEdit;
  const _Composer({required this.controller, required this.editing, required this.error, required this.onSend, required this.onAttach, required this.onCancelEdit});

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.surface1,
    padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.paddingOf(context).bottom + 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 6), child: Align(alignment: Alignment.centerLeft, child: Text(error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)))),
        if (editing) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 6), child: Row(children: [Expanded(child: Text('Changing your message', style: AppTextStyles.hint)), Pressable(onTap: onCancelEdit, semanticLabel: 'Cancel changing', child: Text('Cancel', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText, fontWeight: FontWeight.w700)))])),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!editing) IconButton(tooltip: 'Send a photo, a file or what you agreed', icon: const Icon(Icons.add_circle_outline_rounded), onPressed: onAttach),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(hintText: 'Write a message', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
            ),
            IconButton(tooltip: editing ? 'Save change' : 'Send', icon: Icon(editing ? Icons.check_rounded : Icons.send_rounded, color: AppColors.primaryText), onPressed: onSend),
          ],
        ),
      ],
    ),
  );
}
