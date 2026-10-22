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
import '../../../data/models/job.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/contract/contract_parts.dart';
import '../../widgets/kit/kd_button.dart';
import '../../widgets/kit/kd_card.dart';
import '../../widgets/kit/kd_fields.dart';
import '../../widgets/kit/kd_layout.dart';
import '../../widgets/kit/kd_toast.dart';
import '../../widgets/kit/kd_chip.dart';
import '../../widgets/kit/status_pill.dart';

/// C1 — Post a job (the client's "Post" tab). Category must be one of
/// kSkillCategories, the same list a talent verifies proof against, since
/// applying is gated on verified proof in the job's exact category.
class PostJobScreen extends ConsumerStatefulWidget {
  /// Called after a successful post. The shell switches to "My jobs"; this
  /// screen lives in a tab, so it must not pop a route.
  final VoidCallback? onPosted;

  /// When set, this is the edit form for an open job nobody has applied to
  /// (the server locks the terms once someone applies): it opens filled with
  /// the job, is its own route with a back button, and saves instead of posting.
  final Job? editing;

  const PostJobScreen({super.key, this.onPosted, this.editing});

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
    final job = widget.editing;
    if (job != null) {
      _title.text = job.title;
      _description.text = job.description;
      _budget.text = job.budget.round().toString();
      _category = job.category;
      _deliveryDays = job.deliveryDays ?? 7;
      _descriptionValid = ReasonField.isValid(job.description, min: 20, max: 4000);
    }
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
    final editing = widget.editing;
    try {
      if (editing != null) {
        await ref.read(jobsProvider.notifier).editJob(
              editing.id,
              title: _title.text.trim(),
              category: category,
              description: _description.text.trim(),
              budget: _budgetValue!,
              deliveryDays: _deliveryDays,
            );
      } else {
        await ref.read(jobsProvider.notifier).postJob(
              title: _title.text.trim(),
              category: category,
              description: _description.text.trim(),
              budget: _budgetValue!,
              deliveryDays: _deliveryDays,
            );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      throw const ShownError();
    }
    if (!mounted) return;
    if (editing != null) {
      KdToast.show(context, 'Job updated.');
      Navigator.of(context).pop();
      return;
    }
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
    final editing = widget.editing != null;
    final form = ListView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(AppDimensions.gutter, editing ? MediaQuery.paddingOf(context).top + 8 : 8, AppDimensions.gutter, 140),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (editing)
          const ContractHeader(title: 'Edit job', sub: 'The terms lock once someone applies.', pill: StatusPill('Open', tone: KdTone.brand))
        else
          const ScreenHeader(over: 'New job', title: 'Post a job'),
        const SizedBox(height: 18),
        _Label('Category', error: _tried && _category == null ? 'Pick one' : null),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in kSkillCategories)
              KdChoiceChip(label: c, selected: _category == c, onTap: () => setState(() => _category = c)),
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
                    KdChoiceChip(label: '$d days', selected: _deliveryDays == d, onTap: () => setState(() => _deliveryDays = d)),
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
          NoticeCard(tone: KdTone.bad, icon: Icons.error_outline_rounded, title: editing ? 'Couldn\'t save the changes' : 'Couldn\'t post the job', body: _error),
        ],
        const SizedBox(height: 22),
        KdButton(label: editing ? 'Save changes' : 'Post job', busyLabel: editing ? 'Saving' : 'Posting', onPressed: _submit),
        if (_tried && !_valid) ...[
          const SizedBox(height: 8),
          Text(editing ? 'Fill in the marked fields to save.' : 'Fill in the marked fields to post.', style: AppTextStyles.hint.copyWith(color: AppColors.bad), textAlign: TextAlign.center),
        ],
      ],
    );
    return editing ? Scaffold(body: form) : form;
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
