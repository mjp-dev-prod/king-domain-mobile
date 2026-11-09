import '../kit/info_tip.dart';
import '../../../core/constants/glossary.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/discovery.dart';
import '../contract/contract_parts.dart';
import '../kit/kd_auth.dart';
import '../kit/kd_card.dart';
import '../kit/kd_chip.dart';

/// The answers to a brief while it is being filled in: one place for every screen that asks a brief (posting a job,
/// asking us to find someone, ordering a package) and for a package's own fields.
///
/// A saved brief can seed it before the form's fields are known (editing a job loads the form afterwards): each answer
/// is read from the seed the first time its field is seen, so it lands in the right kind of input.
class BriefAnswers {
  BriefAnswers([Map<String, dynamic>? seed]) : _seed = {...?seed};

  final Map<String, dynamic> _seed;
  final Set<String> _seen = {};
  final Map<String, TextEditingController> _text = {};
  final Map<String, String> _choice = {};
  final Map<String, Set<String>> _many = {};
  final Map<String, bool> _yes = {};

  TextEditingController controller(String key) {
    final c = _text.putIfAbsent(key, TextEditingController.new);
    if (_seen.add(key) && _seed[key] != null && c.text.isEmpty) c.text = '${_seed[key]}';
    return c;
  }

  void _ensure(BriefField f) {
    switch (f.kind) {
      case BriefKind.text:
      case BriefKind.int:
        controller(f.key);
      case BriefKind.choice:
        if (_seen.add(f.key) && _seed[f.key] is String && f.options.contains(_seed[f.key])) _choice[f.key] = _seed[f.key] as String;
      case BriefKind.choices:
        if (_seen.add(f.key) && _seed[f.key] is List) {
          _many[f.key] = {for (final v in _seed[f.key] as List) if (f.options.contains(v)) v as String};
        }
      case BriefKind.yesno:
        if (_seen.add(f.key) && _seed[f.key] is bool) _yes[f.key] = _seed[f.key] as bool;
      case BriefKind.note:
      case BriefKind.milestones:
        break;
    }
  }

  String? choice(BriefField f) {
    _ensure(f);
    return _choice[f.key];
  }

  void choose(BriefField f, String v) => _choice[f.key] = v;

  Set<String> many(BriefField f) {
    _ensure(f);
    return _many.putIfAbsent(f.key, () => <String>{});
  }

  void toggle(BriefField f, String v) {
    final s = many(f);
    if (!s.remove(v)) s.add(v);
  }

  bool? yes(BriefField f) {
    _ensure(f);
    return _yes[f.key];
  }

  void setYes(BriefField f, bool v) => _yes[f.key] = v;

  /// The first problem with these fields, in the words the form uses, or null. Milestones are the caller's.
  String? validate(Iterable<BriefField> fields) {
    for (final f in fields) {
      _ensure(f);
      switch (f.kind) {
        case BriefKind.text:
          final v = controller(f.key).text.trim();
          if (f.required && v.isEmpty) return '${f.label}: fill this in.';
          if (f.max != null && v.length > f.max!) return '${f.label}: keep it under ${f.max} characters.';
        case BriefKind.int:
          final raw = controller(f.key).text.trim();
          if (raw.isEmpty && !f.required) break;
          final n = int.tryParse(raw);
          if (n == null || n < (f.min ?? 0) || n > (f.max ?? 1 << 30)) return '${f.label}: a whole number from ${f.min ?? 0} to ${f.max}.';
        case BriefKind.choice:
          if (f.required && _choice[f.key] == null) return '${f.label}: choose one.';
        case BriefKind.choices:
          if (f.required && (_many[f.key]?.isEmpty ?? true)) return '${f.label}: choose at least one.';
        case BriefKind.yesno:
          if (_yes[f.key] == null) return '${f.label}: answer yes or no.';
        case BriefKind.note:
        case BriefKind.milestones:
          break;
      }
    }
    return null;
  }

  /// What is sent for these fields. A fixed term (`note`) is not sent: the server writes it. Milestones are the caller's.
  Map<String, dynamic> toJson(Iterable<BriefField> fields) {
    final out = <String, dynamic>{};
    for (final f in fields) {
      _ensure(f);
      switch (f.kind) {
        case BriefKind.text:
          final v = controller(f.key).text.trim();
          if (v.isNotEmpty) out[f.key] = v;
        case BriefKind.int:
          final n = int.tryParse(controller(f.key).text.trim());
          if (n != null) out[f.key] = n;
        case BriefKind.choice:
          if (_choice[f.key] != null) out[f.key] = _choice[f.key];
        case BriefKind.choices:
          // In the form's order, so the brief reads the same way for everyone.
          out[f.key] = [for (final o in f.options) if (_many[f.key]?.contains(o) ?? false) o];
        case BriefKind.yesno:
          if (_yes[f.key] != null) out[f.key] = _yes[f.key];
        case BriefKind.note:
        case BriefKind.milestones:
          break;
      }
    }
    return out;
  }

  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
  }
}

/// One question of a brief. Milestones have their own editor and are not drawn here.
class BriefFieldInput extends StatelessWidget {
  final BriefField field;
  final BriefAnswers answers;

  /// Called after a chip is tapped, so the screen can rebuild.
  final VoidCallback onChanged;

  const BriefFieldInput({super.key, required this.field, required this.answers, required this.onChanged});

  static Tip? _tipFor(String key) => switch (key) {
    'usageRights' => Glossary.usageRights,
    'revisionsIncluded' => Glossary.changeRounds,
    _ => null,
  };

  String get _label => field.required || field.kind == BriefKind.yesno ? field.label : '${field.label} (optional)';

  /// A question's heading, with its plain-English tip beside it for the two terms people stumble on.
  Widget _heading(String text, {String? sub}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _tipFor(field.key) == null
          ? Text(text, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600))
          : TitleWithTip(text, _tipFor(field.key)!, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      if (sub != null) Text(sub, style: AppTextStyles.hint),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final f = field;
    switch (f.kind) {
      case BriefKind.text:
        return KdTextField(controller: answers.controller(f.key), label: _label, hintText: f.hint, maxLines: (f.max ?? 0) > 200 ? 3 : 1);
      case BriefKind.int:
        return KdTextField(controller: answers.controller(f.key), label: _label, hintText: f.hint, keyboardType: TextInputType.number);
      case BriefKind.choice:
        final picked = answers.choice(f);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading(_label, sub: f.hint),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in f.options)
              KdChoiceChip(
                label: f.key == 'usageRights' ? usageRightsLabel(o) : o,
                selected: picked == o,
                onTap: () {
                  answers.choose(f, o);
                  onChanged();
                },
              ),
          ]),
        ]);
      case BriefKind.choices:
        final picked = answers.many(f);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading(_label, sub: f.hint ?? (f.required ? 'Pick all that apply, at least one.' : 'Pick all that apply.')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in f.options)
              KdChoiceChip(
                label: o,
                selected: picked.contains(o),
                onTap: () {
                  answers.toggle(f, o);
                  onChanged();
                },
              ),
          ]),
        ]);
      case BriefKind.yesno:
        final v = answers.yes(f);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _heading(_label, sub: f.hint),
          Wrap(spacing: 8, children: [
            KdChoiceChip(
              label: 'Yes',
              selected: v == true,
              onTap: () {
                answers.setYes(f, true);
                onChanged();
              },
            ),
            KdChoiceChip(
              label: 'No',
              selected: v == false,
              onTap: () {
                answers.setYes(f, false);
                onChanged();
              },
            ),
          ]),
        ]);
      case BriefKind.note:
        return NoticeCard(tone: KdTone.plain, icon: Icons.key_outlined, title: f.label, body: f.text ?? '');
      case BriefKind.milestones:
        return const SizedBox.shrink();
    }
  }
}

/// A saved brief value in words: lists joined, yes or no spelled out, usage-rights codes named.
String briefValueText(String key, Object? v) {
  if (v is List) return v.map((e) => '$e').join(', ');
  if (v is bool) return v ? 'Yes' : 'No';
  if (key == 'usageRights') return usageRightsLabel('$v');
  return '$v';
}
