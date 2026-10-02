import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_brand.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/skill_categories.dart';
import '../../../core/formatting/deadline.dart';
import '../../../data/api_client.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/pressable.dart';

/// C1 — Post a job (the client's "Post" tab). Category must be one of
/// kSkillCategories, the same list a talent verifies proof against, since
/// applying is gated on verified proof in the job's exact category.
class PostJobScreen extends ConsumerStatefulWidget {
  /// Called after a successful post. The shell switches to "My jobs"; this
  /// screen lives in a tab, so it must not pop a route.
  final VoidCallback? onPosted;

  const PostJobScreen({super.key, this.onPosted});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  final _scroll = ScrollController();
  String? _category;
  /// Days the talent gets, counted from when the client pays (stage 2:
  /// docs/features/stage-2-delivery-and-changes.md). Backend accepts 1–60.
  int _deliveryDays = 7;
  bool _descriptionValid = false;
  /// Field errors show only after a first attempt, never while typing.
  bool _tried = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _budget.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _budget.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double? get _budgetValue {
    final n = double.tryParse(_budget.text.trim());
    return n == null || n <= 0 ? null : n;
  }

  bool get _valid => _category != null && _title.text.trim().isNotEmpty && _descriptionValid && _budgetValue != null;

  Future<void> _submit() async {
    if (!_valid) {
      setState(() => _tried = true);
      // The marks are on the fields; bring the first ones into view.
      _scroll.animateTo(0, duration: AppMotion.layout, curve: AppMotion.ease);
      return;
    }
    setState(() => _error = null);
    final category = _category!;
    try {
      await ref.read(jobsProvider.notifier).postJob(
            title: _title.text.trim(),
            category: category,
            description: _description.text.trim(),
            budget: _budgetValue!,
            deliveryDays: _deliveryDays,
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    KdToast.show(context, 'Job posted. Students verified in $category can apply now.');
    FocusScope.of(context).unfocus();
    setState(() {
      _title.clear();
      _description.clear();
      _budget.clear();
      _category = null;
      _deliveryDays = 7;
      _tried = false;
    });
    final onPosted = widget.onPosted;
    if (onPosted != null) {
      onPosted();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final due = DateTime.now().add(Duration(days: _deliveryDays));
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 8, AppDimensions.gutter, 140),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const ScreenHeader(over: 'New job', title: 'Post a job'),
        const SizedBox(height: 18),
        _Label('Category', error: _tried && _category == null ? 'Pick one' : null),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kSkillCategories)
              _Chip(label: c, selected: _category == c, onTap: () => setState(() => _category = c)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Only students verified in this category can apply.', style: AppTextStyles.hint),
        const SizedBox(height: 20),
        _Label('Title', error: _tried && _title.text.trim().isEmpty ? 'Required' : null),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 120,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          style: AppTextStyles.bodyMedium,
          decoration: const InputDecoration(hintText: 'e.g. Landing page redesign for a campus app'),
        ),
        ReasonField(
          controller: _description,
          label: 'What needs doing',
          hint: 'Scope, what you expect to receive, and anything the talent needs to know.',
          min: 20,
          max: 4000,
          onValidChanged: (v) => setState(() => _descriptionValid = v),
        ),
        const SizedBox(height: 4),
        _Label('Budget', error: _tried && _budgetValue == null ? 'Enter an amount' : null),
        const SizedBox(height: 8),
        TextField(
          controller: _budget,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.money, fontFeatures: const [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            hintText: '45000',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Text('₦', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.money)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'The talent receives all of it. When you pick someone, you pay this plus ${AppBrand.name}\'s fee, held until you approve the work.',
          style: AppTextStyles.hint,
        ),
        const SizedBox(height: 20),
        const _Label('Time to deliver'),
        const SizedBox(height: 8),
        KdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in const [3, 5, 7, 14])
                    _Chip(label: '$d days', selected: _deliveryDays == d, onTap: () => setState(() => _deliveryDays = d)),
                ],
              ),
              const SizedBox(height: 12),
              DayStepper(value: _deliveryDays, min: 1, max: 60, onChanged: (v) => setState(() => _deliveryDays = v)),
              const SizedBox(height: 10),
              Text(
                'The clock starts when you pay. Paid now, it would be due ${formatDeadline(due)}.',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: 'Couldn\'t post the job', body: _error),
        ],
        const SizedBox(height: 22),
        KdButton(label: 'Post job', busyLabel: 'Posting', onPressed: _submit),
        if (_tried && !_valid) ...[
          const SizedBox(height: 8),
          Text('Fill in the marked fields to post.', style: AppTextStyles.hint.copyWith(color: AppColors.bad), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? error;
  const _Label(this.text, {this.error});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600))),
          if (error != null) Text(error!, style: AppTextStyles.hint.copyWith(color: AppColors.bad)),
        ],
      );
}

/// A selectable chip with a real selected state (violet-soft fill, violet
/// text, a check) and a spring pop on selection.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      semanticLabel: label,
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : AppMotion.state,
        curve: AppMotion.spring,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface1,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 16, color: AppColors.primaryText),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
                color: selected ? AppColors.primaryText : AppColors.text2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
