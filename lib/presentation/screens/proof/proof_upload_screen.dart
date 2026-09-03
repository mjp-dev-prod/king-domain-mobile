import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/talent_profile.dart';
import '../../providers/talent_profile_provider.dart';
import '../../widgets/common/onboarding_step_header.dart';
import '../shell/app_shell.dart';

/// T3 — Proof Upload. One work sample per skill category, submitted for
/// human review (Milestone 03: self-submitted work samples, human-reviewed,
/// one-time per category, permanent). Nothing here auto-verifies — every
/// item starts `pending` until a King Domain reviewer approves it, and a
/// talent can't apply to jobs in a category until it's verified there.
class ProofUploadScreen extends ConsumerStatefulWidget {
  const ProofUploadScreen({super.key});

  @override
  ConsumerState<ProofUploadScreen> createState() => _ProofUploadScreenState();
}

class _ProofUploadScreenState extends ConsumerState<ProofUploadScreen> {
  Future<void> _addProof(String category) async {
    final titleController = TextEditingController();
    String? pickedPath;

    final confirmed = await showModalBottomSheet<bool>(
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
                  ),
                  const SizedBox(height: AppDimensions.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (file != null) {
                        setSheetState(() => pickedPath = file.path);
                      }
                    },
                    icon: const Icon(Icons.attach_file, size: AppDimensions.iconSm),
                    label: Text(
                      pickedPath == null
                          ? 'Attach a file or screenshot'
                          : 'Attached ✓',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  ElevatedButton(
                    onPressed: titleController.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Submit for review'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (confirmed == true && titleController.text.trim().isNotEmpty) {
      ref
          .read(talentProfileProvider.notifier)
          .addProofItem(
            ProofItem(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              category: category,
              title: titleController.text.trim(),
              filePath: pickedPath,
            ),
          );
    }
  }

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(talentProfileProvider);
    final categories = profile.skillCategories;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          children: [
            const OnboardingStepHeader(
              step: 3,
              totalSteps: 3,
              title: 'Upload proof',
              subtitle:
                  'One work sample per category. A King Domain reviewer '
                  'checks it before you can apply to jobs in that category.',
            ),
            const SizedBox(height: AppDimensions.xl),
            for (final category in categories) ...[
              _CategoryProofSection(
                category: category,
                items: profile.proofItems
                    .where((p) => p.category == category)
                    .toList(),
                onAdd: () => _addProof(category),
                onRemove: (id) => ref
                    .read(talentProfileProvider.notifier)
                    .removeProofItem(id),
                onSimulateApprove: (id) => ref
                    .read(talentProfileProvider.notifier)
                    .simulateReviewApproval(id),
              ),
              const SizedBox(height: AppDimensions.lg),
            ],
            const SizedBox(height: AppDimensions.md),
            ElevatedButton(
              onPressed: profile.proofItems.isEmpty ? null : _finish,
              child: const Text('Finish setup'),
            ),
            if (profile.proofItems.isEmpty) ...[
              const SizedBox(height: AppDimensions.sm),
              Center(
                child: Text(
                  'Add at least one proof item to continue.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ],
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
  final ValueChanged<String> onSimulateApprove;

  const _CategoryProofSection({
    required this.category,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.onSimulateApprove,
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
                (item) => _ProofItemTile(
                  item: item,
                  onRemove: onRemove,
                  onSimulateApprove: onSimulateApprove,
                ),
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
  final ValueChanged<String> onSimulateApprove;

  const _ProofItemTile({
    required this.item,
    required this.onRemove,
    required this.onSimulateApprove,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = item.status == ProofReviewStatus.verified;
    final statusColor = isVerified ? AppColors.settled : AppColors.openPending;
    final statusText = isVerified ? 'Verified' : 'Pending review · tap to simulate approval';

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(item.title, style: AppTextStyles.bodyMedium),
          ),
          GestureDetector(
            onTap: isVerified ? null : () => onSimulateApprove(item.id),
            child: Container(
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
          ),
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
