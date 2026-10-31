import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/identity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/identity_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/evidence_viewer.dart' show formatBytes;
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_sheet.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/pressable.dart';
import '../../widgets/kit/status_pill.dart';

/// The form that sends an identity document and a short live video to the checker (PRD §3.1 step 4).
/// Until a provider is live (CAC), a person checks it by hand (D47).
class IdentitySubmitScreen extends ConsumerStatefulWidget {
  const IdentitySubmitScreen({super.key});

  @override
  ConsumerState<IdentitySubmitScreen> createState() => _IdentitySubmitScreenState();
}

class _IdentitySubmitScreenState extends ConsumerState<IdentitySubmitScreen> {
  final _name = TextEditingController();
  final _number = TextEditingController();
  IdentityDocument _document = IdentityDocument.ninSlip;
  DateTime? _dob;
  XFile? _photo;
  XFile? _video;
  int? _photoBytes;
  int? _videoBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(authProvider).user?.fullName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  bool get _isClient => ref.read(authProvider).user?.role == 'client';
  bool get _needsVideo => _document != IdentityDocument.cac;

  Future<void> _pickPhoto() async {
    final source = await showKdSheet<ImageSource>(
      context,
      builder: (sheet) => KdSheetBody(
        title: 'Photo of your ${_document.label.toLowerCase()}',
        lead: 'Lay it flat in good light. All four corners and every word must be readable.',
        children: [
          const SizedBox(height: 12),
          KdButton(label: 'Take a photo', icon: Icons.photo_camera_outlined, onPressed: () => Navigator.of(sheet).pop(ImageSource.camera)),
          const SizedBox(height: 8),
          KdButton.secondary(label: 'Choose from gallery', onPressed: () => Navigator.of(sheet).pop(ImageSource.gallery)),
        ],
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 88);
    if (picked == null) return;
    final size = await picked.length();
    setState(() {
      _photo = picked;
      _photoBytes = size;
    });
  }

  Future<void> _recordVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, maxDuration: const Duration(seconds: 15));
    if (picked == null) return;
    final size = await picked.length();
    if (size > 24 * 1024 * 1024) {
      setState(() => _error = 'That video is too big (${formatBytes(size)}). Record a shorter one, up to 15 seconds.');
      return;
    }
    setState(() {
      _video = picked;
      _videoBytes = size;
      _error = null;
    });
  }

  Future<void> _chooseDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, 1, 1),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 13, 12, 31),
      helpText: 'Date of birth, as on the document',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String? _problem() {
    if (_name.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length < 2) return 'Enter your full name as it appears on the document.';
    if (_document == IdentityDocument.ninSlip && !RegExp(r'^\d{11}$').hasMatch(_number.text.trim())) return 'Your NIN is 11 digits.';
    if (_document != IdentityDocument.ninSlip && _number.text.trim().length < 5) return 'Enter the document number.';
    if (_document != IdentityDocument.cac && _dob == null) return 'Choose your date of birth.';
    if (_photo == null) return 'Add a clear photo of the document.';
    if (_needsVideo && _video == null) return 'Record the short video of your face.';
    return null;
  }

  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      throw const ShownError();
    }
    setState(() => _error = null);
    try {
      final photoBytes = await _photo!.readAsBytes();
      final videoBytes = _needsVideo ? await _video!.readAsBytes() : null;
      await ref.read(identityActionsProvider).submitIdentity(
        document: _document,
        number: _number.text.trim(),
        fullName: _name.text.trim(),
        dateOfBirth: _dob == null ? null : _date(_dob!),
        documentBytes: photoBytes,
        documentName: _photo!.name,
        videoBytes: videoBytes,
        videoName: _video?.name,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Sent. A person will check it.');
    Navigator.of(context).pop(true);
  }

  Widget _attachTile({required IconData icon, required String empty, required String? filled, required String? meta, required VoidCallback onTap}) {
    final has = filled != null;
    return Pressable(
      onTap: onTap,
      semanticLabel: has ? '$filled. Tap to replace.' : empty,
      child: KdCard(
        tone: has ? KdTone.ok : KdTone.plain,
        child: Row(children: [
          Icon(has ? Icons.check_circle_outline_rounded : icon, color: has ? AppColors.ok : AppColors.primaryText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(has ? filled : empty, style: AppTextStyles.title),
              if (meta != null) Text(meta, style: AppTextStyles.hint),
            ]),
          ),
          Text(has ? 'Replace' : 'Add', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _isClient ? IdentityDocument.values : const [IdentityDocument.ninSlip, IdentityDocument.passport];
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
        children: [
          const ContractHeader(title: 'Your ID', sub: 'A person checks this by hand, usually within 2 days. Only the checker sees it.', pill: StatusPill('Step 2 of 2', tone: KdTone.brand)),
          const SizedBox(height: 16),
          Text('Document', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in docs) KdChoiceChip(label: d.label, selected: _document == d, onTap: () => setState(() => _document = d)),
          ]),
          if (_document == IdentityDocument.passport) ...[
            const SizedBox(height: 6),
            Text('For people outside Nigeria, or without a NIN.', style: AppTextStyles.hint),
          ],
          const SizedBox(height: 16),
          KdTextField(controller: _name, label: _document == IdentityDocument.cac ? 'Name of the person registering the business' : 'Full name, as on the document', textInputAction: TextInputAction.next),
          const SizedBox(height: 14),
          KdTextField(controller: _number, label: _document.numberLabel, keyboardType: _document == IdentityDocument.ninSlip ? TextInputType.number : TextInputType.text, textInputAction: TextInputAction.done),
          if (_document != IdentityDocument.cac) ...[
            const SizedBox(height: 14),
            Pressable(
              onTap: _chooseDob,
              semanticLabel: 'Date of birth',
              child: KdCard(
                child: Row(children: [
                  const Icon(Icons.cake_outlined, color: AppColors.primaryText),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_dob == null ? 'Date of birth' : _date(_dob!), style: AppTextStyles.title.copyWith(color: _dob == null ? AppColors.text3 : AppColors.text))),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _attachTile(
            icon: Icons.badge_outlined,
            empty: 'Photo of the document',
            filled: _photo == null ? null : 'Document photo added',
            meta: _photoBytes == null ? 'Clear, flat, every word readable' : formatBytes(_photoBytes!),
            onTap: _pickPhoto,
          ),
          if (_needsVideo) ...[
            const SizedBox(height: 10),
            _attachTile(
              icon: Icons.videocam_outlined,
              empty: 'Record a short video of your face',
              filled: _video == null ? null : 'Video recorded',
              meta: _videoBytes == null ? 'Look at the camera, say your name, turn your head left and right. 5 to 15 seconds.' : formatBytes(_videoBytes!),
              onTap: _recordVideo,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)),
          ],
          const SizedBox(height: 20),
          KdButton(label: 'Send for checking', busyLabel: 'Sending', onPressed: _submit),
          const SizedBox(height: 10),
          Text('The video can be a few MB. On mobile data it uses about as much as a short WhatsApp video.', textAlign: TextAlign.center, style: AppTextStyles.hint),
        ],
      ),
    );
  }
}
