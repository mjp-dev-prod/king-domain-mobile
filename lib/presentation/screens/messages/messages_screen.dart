import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/models/messaging.dart';
import '../../providers/auth_provider.dart';
import '../../providers/messaging_provider.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/motion.dart';
import 'conversation_screen.dart';

/// Messages (PRD §4.7): one conversation per person, with how many are waiting. The same tab for both roles.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);
    final isClient = ref.watch(authProvider).user?.role == 'client';

    final Widget body = async.when(
      loading: () => const Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
      error: (_, _) => ErrorState(message: "Couldn't load your messages. Check your connection and try again.", onRetry: () async => ref.invalidate(conversationsProvider)),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            body: isClient
                ? 'Message someone who applied to your job, or whom you invited. Keep everything inside King Domain: it protects you both.'
                : 'Clients message you once you have applied, or when they invite you. Everything stays inside King Domain, which keeps you safe.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RiseIn(
                  key: ValueKey(list[i].id),
                  delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                  child: _Tile(c: list[i], onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversationId: list[i].id)))),
                ),
              ),
          ],
        );
      },
    );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(conversationsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 8, AppDimensions.gutter, 120),
        children: [
          const ScreenHeader(title: 'Messages'),
          const SizedBox(height: 12),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final ConversationSummary c;
  final VoidCallback onTap;
  const _Tile({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = c.preview == null ? 'No messages yet' : '${c.lastMine ? 'You: ' : ''}${c.lastHeld ? 'Not sent. ' : ''}${c.preview}';
    return KdCard(
      onTap: onTap,
      child: Row(
        children: [
          UserAvatar(name: c.otherName, photoUrl: c.otherPhotoUrl, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(c.otherName, style: AppTextStyles.title.copyWith(fontWeight: c.unread > 0 ? FontWeight.w800 : FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  if (c.lastAt != null) Text(formatAgo(c.lastAt!), style: AppTextStyles.hint),
                ]),
                const SizedBox(height: 2),
                Text(
                  c.blocked ? 'Blocked' : preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(color: c.unread > 0 ? AppColors.text : AppColors.text2, fontWeight: c.unread > 0 ? FontWeight.w600 : FontWeight.w400),
                ),
              ],
            ),
          ),
          if (c.unread > 0) ...[
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(99)),
              child: Semantics(label: '${c.unread} unread', child: Text('${c.unread}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
            ),
          ],
        ],
      ),
    );
  }
}
