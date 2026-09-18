import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/talent_profile_provider.dart';

/// Proof Upload. One work sample per skill category, submitted for human
/// review (Milestone 03: self-submitted work samples, human-reviewed,
/// one-time per category, permanent). Real upload now (multer -> Supabase
/// Storage — Sprint 2/4): the file picked here is genuinely sent to the
/// backend, not just remembered as a local device path. There is no
/// self-approve anymore — simulateReviewApproval() is gone; verification
/// only happens through the real admin reviewer flow
/// (backend/src/admin/proofReviewRoutes.js), which has no UI in this app.
/// Reached from ProfileOverviewScreen, not a forced onboarding step.
class ProofUploadScreen extends ConsumerStatefulWidget {
  const ProofUploadScreen({super.key});

  @override
  ConsumerState<ProofUploadScreen> createState() => _ProofUploadScreenState();
}

class _ProofUploadScreenState extends ConsumerState<ProofUploadScreen> {
  Future<void> _addProof(String category) async {
    final titleController = TextEditingController();
    XFile? pickedFile;
    bool submitting = false;
    String? sheetError;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.lg,
            right: AppDimensions.lg,
            top: AppDimensions.lg,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom +
                AppDimensions.lg,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add proof — $category', style: AppTextStyles.h3),
                  const SizedBox(height: AppDimensions.md),
                  TextField(
                    controller: titleController,
                    style: AppTextStyles.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'What is this?',
                      hintText: 'e.g. E-commerce app redesign, portfolio site',
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (file != null) {
                        setSheetState(() => pickedFile = file);
                      }
                    },
                    icon: const Icon(Icons.attach_file, size: AppDimensions.iconSm),
                    label: Text(
                      pickedFile == null
                          ? 'Attach a file or screenshot'
                          : 'Attached ✓',
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      sheetError!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.lg),
                  ElevatedButton(
                    onPressed: (titleController.text.trim().isEmpty || submitting)
                        ? null
                        : () async {
                            setSheetState(() => submitting = true);
                            try {
                              final bytes = pickedFile != null
                                  ? await File(pickedFile!.path).readAsBytes()
                                  : null;
                              await ref.read(talentProfileProvider.notifier).addProofItem(
                                    category: category,
                                    title: titleController.text.trim(),
                                    fileBytes: bytes,
                                    fileName: pickedFile?.name,
                                  );
                              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                            } on ApiException catch (e) {
                              setSheetState(() {
                                submitting = false;
                                sheetError = e.message;
                              });
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Submit for review'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _finish() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(talentProfileProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Could not load your profile.', style: AppTextStyles.bodyMedium),
          ),
          data: (profile) {
            final categories = profile.skillCategories;

            return ListView(
              padding: const EdgeInsets.all(AppDimensions.lg),
              children: [
                Text('Upload proof', style: AppTextStyles.h2),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  'One work sample per category. A King Domain reviewer '
                  'checks it before you can apply to jobs in that category.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.slateDim),
                ),
                const SizedBox(height: AppDimensions.xl),
                for (final category in categories) ...[
                  _CategoryProofSection(
                    category: category,
                    items: profile.proofItems
                        .where((p) => p.category == category)
                        .toList(),
                    onAdd: () => _addProof(category),
                    onRemove: (id) =>
                        ref.read(talentProfileProvider.notifier).removeProofItem(id),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                ],
                const SizedBox(height: AppDimensions.md),
                ElevatedButton(
                  onPressed: _finish,
                  child: const Text('Done'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryProofSection extends StatelessWidget {
  final String category;
  final List<ProofItem> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _CategoryProofSection({
    required this.category,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    category,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: AppDimensions.iconSm),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (items.isEmpty)
              Text(
                'No proof submitted yet — you can\'t apply to jobs in this '
                'category until you do.',
                style: AppTextStyles.bodySmall,
              )
            else
              ...items.map(
                (item) => _ProofItemTile(item: item, onRemove: onRemove),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProofItemTile extends StatelessWidget {
  final ProofItem item;
  final ValueChanged<String> onRemove;

  const _ProofItemTile({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isVerified = item.status == ProofReviewStatus.verified;
    final statusColor = isVerified ? AppColors.settled : AppColors.openPending;
    final statusText = isVerified ? 'Verified' : 'Pending human review';

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppDimensions.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(
                    statusText,
                    style: AppTextStyles.bodySmall.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          if (!isVerified)
            IconButton(
              icon: const Icon(
                Icons.close,
                size: AppDimensions.iconSm,
                color: AppColors.slateDim,
              ),
              onPressed: () => onRemove(item.id),
            ),
        ],
      ),
    );
  }
}
