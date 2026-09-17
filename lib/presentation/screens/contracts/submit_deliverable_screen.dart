import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/common/section_label.dart';

/// Reuses the attach-a-file interaction already built for proof upload
/// (proof_upload_screen.dart) — same pattern, different purpose: this
/// submits the finished deliverable against a funded contract rather than
/// a portfolio sample. The file is genuinely uploaded now (backend's
/// /jobs/:id/contract/submit takes multipart — Contract.deliverableFilePath,
/// a private Supabase Storage path resolved to a signed URL on read, same
/// shape as ProofItem.filePath).
class SubmitDeliverableScreen extends ConsumerStatefulWidget {
  final String jobId;

  const SubmitDeliverableScreen({super.key, required this.jobId});

  @override
  ConsumerState<SubmitDeliverableScreen> createState() =>
      _SubmitDeliverableScreenState();
}

class _SubmitDeliverableScreenState
    extends ConsumerState<SubmitDeliverableScreen> {
  final _noteController = TextEditingController();
  XFile? _pickedFile;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _pickedFile = file);
  }

  Future<void> _submit() async {
    if (_noteController.text.trim().isEmpty || _pickedFile == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final bytes = await File(_pickedFile!.path).readAsBytes();
      await ref.read(jobsProvider.notifier).submitDeliverable(
            widget.jobId,
            _noteController.text.trim(),
            fileBytes: bytes,
            fileName: _pickedFile!.name,
          );
      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deliverable submitted for review.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        !_submitting && _noteController.text.trim().isNotEmpty && _pickedFile != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit deliverable')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          children: [
            const SectionLabel('Attach your work'),
            const SizedBox(height: AppDimensions.sm),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file, size: AppDimensions.iconSm),
              label: Text(_pickedFile == null ? 'Attach the finished file' : 'Attached ✓'),
            ),
            const SizedBox(height: AppDimensions.lg),
            const SectionLabel('Note to client'),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _noteController,
              onChanged: (_) => setState(() {}),
              style: AppTextStyles.bodyMedium,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Describe what you\'re delivering, any notes on '
                    'revisions or how to use the file.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppDimensions.xl),
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.openPending.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.openPending.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: AppDimensions.iconSm, color: AppColors.openPending),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      'Once submitted, the client reviews your work. Payment '
                      'releases when they approve it.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppDimensions.md),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.openPending),
              ),
            ],
            const SizedBox(height: AppDimensions.xl),
            ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.ink,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text('Submit for review'),
            ),
          ],
        ),
      ),
    );
  }
}
