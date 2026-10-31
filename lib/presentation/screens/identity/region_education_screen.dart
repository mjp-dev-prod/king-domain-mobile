import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';
import '../../../data/models/identity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/identity_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_auth.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart' show KdTone;
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/motion.dart';
import '../../widgets/kit/status_pill.dart';

/// Nigeria's 36 states and the FCT, for the state picker.
const nigerianStates = [
  'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno', 'Cross River', 'Delta',
  'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT Abuja', 'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina',
  'Kebbi', 'Kogi', 'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau',
  'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara',
];

/// Where the person is, and how they describe their training (talents) or whether they hire as an
/// individual or a business (clients). Describes, never gates (PRD §3.1 step 2; D15).
class RegionEducationScreen extends ConsumerStatefulWidget {
  const RegionEducationScreen({super.key});

  @override
  ConsumerState<RegionEducationScreen> createState() => _RegionEducationScreenState();
}

class _RegionEducationScreenState extends ConsumerState<RegionEducationScreen> {
  final _country = TextEditingController(text: 'Nigeria');
  final _city = TextEditingController();
  final _school = TextEditingController();
  final _detail = TextEditingController();
  String? _state;
  EducationKind? _kind;
  String? _clientKind;
  bool _filled = false;
  String? _error;

  @override
  void dispose() {
    _country.dispose();
    _city.dispose();
    _school.dispose();
    _detail.dispose();
    super.dispose();
  }

  bool get _isClient => ref.read(authProvider).user?.role == 'client';
  bool get _inNigeria => _country.text.trim().toLowerCase() == 'nigeria';

  void _prefill(AboutYou about) {
    if (_filled) return;
    _filled = true;
    final r = about.region;
    if (r != null) {
      _country.text = r.country;
      _state = r.state;
      _city.text = r.city ?? '';
    }
    final e = about.education;
    if (e != null) {
      _kind = e.kind;
      _school.text = e.school ?? '';
      _detail.text = e.detail ?? '';
    }
    _clientKind = about.clientKind;
  }

  String? _problem() {
    if (_country.text.trim().isEmpty) return 'Enter your country.';
    if (_inNigeria && (_state == null || _state!.isEmpty)) return 'Choose your state.';
    if (_isClient) return _clientKind == null ? 'Say whether you hire as an individual or a business.' : null;
    final k = _kind;
    if (k == null) return 'Choose how to describe your training.';
    if (k.needsSchool && _school.text.trim().isEmpty) return k == EducationKind.student ? 'Add your school.' : 'Add the school you graduated from.';
    if (k.needsDetail && _detail.text.trim().isEmpty) return k == EducationKind.student ? 'Add the session you are in.' : k == EducationKind.graduate ? 'Add the year you graduated.' : 'Add the course or camp.';
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      throw const ShownError();
    }
    setState(() => _error = null);
    try {
      await ref.read(identityActionsProvider).saveAboutYou(
        country: _country.text.trim(),
        state: _inNigeria ? _state : null,
        city: _city.text.trim(),
        educationKind: _isClient ? null : _kind,
        school: _kind?.needsSchool == true || _kind == EducationKind.trained ? _school.text.trim() : null,
        detail: _kind?.needsDetail == true ? _detail.text.trim() : null,
        clientKind: _isClient ? _clientKind : null,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final about = ref.watch(aboutYouProvider);
    final isClient = ref.watch(authProvider).user?.role == 'client';
    return Scaffold(
      body: about.when(
        loading: () => ListView(padding: const EdgeInsets.all(AppDimensions.gutter), children: const [SizedBox(height: 40), Skeleton(height: 26, width: 220, radius: 8), SizedBox(height: 20), SkeletonCard(), SizedBox(height: 12), SkeletonCard()]),
        error: (_, _) => Center(child: ErrorState(message: "Couldn't load your details. Check your connection and try again.", onRetry: () async => ref.invalidate(aboutYouProvider))),
        data: (data) {
          _prefill(data);
          return ListView(
            padding: EdgeInsets.fromLTRB(AppDimensions.gutter, MediaQuery.paddingOf(context).top + 8, AppDimensions.gutter, 40),
            children: [
              ContractHeader(
                title: 'About you',
                sub: isClient ? 'Where you are, and whether you hire as an individual or a business.' : 'Where you are, and how you describe your training. Clients see this; it never limits what you can do.',
                pill: StatusPill(data.isDoneFor(isClient) ? 'Saved' : 'To do', tone: data.isDoneFor(isClient) ? KdTone.ok : KdTone.brand),
              ),
              const SizedBox(height: 16),
              KdTextField(controller: _country, label: 'Country', textInputAction: TextInputAction.next, onSubmitted: (_) => setState(() {})),
              const SizedBox(height: 14),
              if (_inNigeria) ...[
                Text('State', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _state,
                  isExpanded: true,
                  dropdownColor: AppColors.surface2,
                  decoration: const InputDecoration(hintText: 'Choose your state'),
                  items: [for (final s in nigerianStates) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => setState(() => _state = v),
                ),
                const SizedBox(height: 14),
              ],
              KdTextField(controller: _city, label: 'City or area (optional)', textInputAction: TextInputAction.next),
              const SizedBox(height: 22),
              if (isClient) ...[
                Text('I hire as', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  KdChoiceChip(label: 'An individual', selected: _clientKind == 'individual', onTap: () => setState(() => _clientKind = 'individual')),
                  KdChoiceChip(label: 'A business', selected: _clientKind == 'business', onTap: () => setState(() => _clientKind = 'business')),
                ]),
              ] else ...[
                Text('How would you describe yourself?', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final k in EducationKind.values) KdChoiceChip(label: k.label, selected: _kind == k, onTap: () => setState(() => _kind = k)),
                ]),
                if (_kind != null && _kind != EducationKind.selfTaught) ...[
                  const SizedBox(height: 14),
                  if (_kind!.needsSchool || _kind == EducationKind.trained)
                    KdTextField(controller: _school, label: _kind!.schoolHint, textInputAction: TextInputAction.next),
                  if (_kind!.needsSchool || _kind == EducationKind.trained) const SizedBox(height: 14),
                  KdTextField(controller: _detail, label: _kind!.detailHint),
                ],
                const SizedBox(height: 10),
                Text('Same checks for everyone: your work and your identity decide what you can do, not your schooling.', style: AppTextStyles.hint),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.bad)),
              ],
              const SizedBox(height: 22),
              KdButton(label: 'Save', busyLabel: 'Saving', onPressed: _save),
            ],
          );
        },
      ),
    );
  }
}
