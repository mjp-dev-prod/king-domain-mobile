import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_image.dart';
import '../../widgets/kit/kd_image_pick.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';
import '../profile/profile_builder_screen.dart';

/// Proof of work: one work sample per skill category, checked by a person
/// (Milestone 03: self-submitted, human-reviewed, permanent once verified).
/// Verification happens only in the admin reviewer flow
/// (backend/src/admin/proofReviewRoutes.js), never in this app.
class ProofUploadScreen extends ConsumerWidget {
  const ProofUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(talentProfileProvider);
    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: ErrorState(
            message: 'Couldn\'t load your proof. Check your connection and try again.',
            onRetry: () => ref.read(talentProfileProvider.notifier).refresh(),
          ),
        ),
        data: (profile) {
          final categories = profile.skillCategories;
          return RefreshIndicator(
            // Signed image links last 5 minutes; pulling gets fresh ones.
            onRefresh: () => ref.read(talentProfileProvider.notifier).refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
              children: [
                ContractHeader(
                  title: 'Proof of work',
                  sub: 'One work sample per category. A ${AppBrand.name} reviewer checks it before you can apply to jobs in that category.',
                  pill: StatusPill('${profile.proofItems.where((p) => p.status == ProofReviewStatus.verified).length} verified', tone: KdTone.ok),
                ),
                const SizedBox(height: 14),
                if (categories.isEmpty)
                  EmptyState(
                    icon: Icons.category_outlined,
                    title: 'Pick your categories first',
                    body: 'Proof is submitted per category. Choose the ones you work in on your profile.',
                    actionLabel: 'Edit profile',
                    onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileBuilderScreen())),
                  ),
                for (var i = 0; i < categories.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RiseIn(
                      delay: Duration(milliseconds: 60 * i),
                      child: _CategoryCard(
                        category: categories[i],
                        items: profile.proofItems.where((p) => p.category == categories[i]).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final String category;
  final List<ProofItem> items;
  const _CategoryCard({required this.category, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = items.any((p) => p.status == ProofReviewStatus.verified);
    final inReview = !verified && items.isNotEmpty;
    return KdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(category, style: AppTextStyles.title)),
              if (verified)
                const StatusPill('Verified', tone: KdTone.ok, icon: Icons.verified_outlined)
              else if (inReview)
                const StatusPill('In review', tone: KdTone.warn)
              else
                const StatusPill('No proof yet'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            verified
                ? 'You can apply to $category jobs.'
                : inReview
                    ? 'A reviewer will check it. You\'ll get an email either way.'
                    : 'You can\'t apply to $category jobs until a sample is verified.',
            style: AppTextStyles.bodySmall,
          ),
          for (final item in items) ...[
            const SizedBox(height: 12),
            _ProofRow(item: item),
          ],
          if (!verified) ...[
            const SizedBox(height: 14),
            KdButton(
              label: items.isEmpty ? 'Add a work sample' : 'Add another sample',
              icon: Icons.add_rounded,
              variant: KdButtonVariant.soft,
              height: AppDimensions.buttonHeightSm,
              onPressed: () { _openAdd(context, ref, category); },
            ),
          ],
        ],
      ),
    );
  }
}

class _ProofRow extends ConsumerWidget {
  final ProofItem item;
  const _ProofRow({required this.item});

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showKdSheet(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Remove "${item.title}"?',
        lead: 'It\'s withdrawn from review and deleted. You can submit a new sample any time.',
        children: [
          const SizedBox(height: 18),
          KdButton(
            label: 'Remove sample',
            variant: KdButtonVariant.danger,
            busyLabel: 'Removing',
            onPressed: () async {
              final nav = Navigator.of(sheet);
              try {
                await ref.read(talentProfileProvider.notifier).removeProofItem(item.id);
              } on ApiException catch (e) {
                if (sheet.mounted) KdToast.show(sheet, e.message, kind: ToastKind.error);
                throw const ShownError();
              }
              nav.pop();
            },
          ),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Keep it', onPressed: () => Navigator.of(sheet).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = item.status == ProofReviewStatus.verified;
    return Row(
      children: [
        SizedBox(width: 72, height: 54, child: WorkImage(url: item.fileUrl, radius: AppDimensions.radiusSm)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(verified ? 'Verified' : 'Waiting for a reviewer', style: AppTextStyles.hint.copyWith(color: verified ? AppColors.ok : AppColors.warn)),
            ],
          ),
        ),
        // Verified samples are permanent; only ones in review can be withdrawn.
        if (!verified)
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _confirmRemove(context, ref),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.text3),
          ),
      ],
    );
  }
}

void _openAdd(BuildContext context, WidgetRef ref, String category) {
  showKdSheet(context, builder: (_) => _AddProofSheet(category: category));
}

class _AddProofSheet extends ConsumerStatefulWidget {
  final String category;
  const _AddProofSheet({required this.category});

  @override
  ConsumerState<_AddProofSheet> createState() => _AddProofSheetState();
}

class _AddProofSheetState extends ConsumerState<_AddProofSheet> {
  final _title = TextEditingController();
  XFile? _file;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final file = _file;
    try {
      await ref.read(talentProfileProvider.notifier).addProofItem(
            category: widget.category,
            title: _title.text.trim(),
            fileBytes: file == null ? null : await File(file.path).readAsBytes(),
            fileName: file?.name,
          );
    } on ApiException catch (e) {
      if (mounted) KdToast.show(context, e.message, kind: ToastKind.error);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Sent for review. We\'ll email you when it\'s checked.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return KdSheetBody(
      title: 'Add a work sample',
      lead: widget.category,
      children: [
        const SizedBox(height: 16),
        ImagePickField(file: _file, onChanged: (f) => setState(() => _file = f), emptyLabel: 'Attach a screenshot of the work'),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          maxLength: 120,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyles.bodyMedium,
          decoration: const InputDecoration(labelText: 'What is it?', hintText: 'e.g. Logo and menu for a campus cafe'),
        ),
        const SizedBox(height: 6),
        Text('Reviewers can only verify what they can see, so attach the work itself.', style: AppTextStyles.hint),
        const SizedBox(height: 18),
        KdButton(
          label: 'Send for review',
          busyLabel: _file == null ? 'Sending' : 'Uploading',
          onPressed: _title.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}
