import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import 'kd_button.dart';
import 'kd_card.dart';

class ConsentDetails {
  final String title;
  final String purpose;
  final List<String> collected;
  final String whoSees;
  final String keptFor;
  final String rights;
  final String agreeLabel;
  const ConsentDetails({
    required this.title,
    required this.purpose,
    required this.collected,
    required this.whoSees,
    required this.keptFor,
    required this.rights,
    required this.agreeLabel,
  });
}

/// Shown before collecting anything sensitive: identity, selfies, documents,
/// addresses, call notes (NDPA s.26–27; PRD §4.4). It says who, why, what,
/// who sees it, how long it is kept, and the person's rights, and consent is
/// an active tick, never pre-selected.
class ConsentScreen extends StatefulWidget {
  final ConsentDetails details;
  final Future<void> Function() onAgree;
  final VoidCallback? onDecline;
  const ConsentScreen({super.key, required this.details, required this.onAgree, this.onDecline});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _ticked = false;

  Widget _section(String heading, Widget body) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(heading.toUpperCase(), style: AppTextStyles.label.copyWith(color: AppColors.text3)),
      const SizedBox(height: 4),
      body,
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final d = widget.details;
    final body = AppTextStyles.bodyMedium.copyWith(color: AppColors.text2, height: 1.5);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 16, AppDimensions.gutter, 16),
                children: [
                  Text(d.title, style: AppTextStyles.h2),
                  const SizedBox(height: 8),
                  Text(d.purpose, style: body),
                  const SizedBox(height: 18),
                  KdCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _section(
                        'What we collect',
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final c in d.collected) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(c, style: body)),
                        ]),
                      ),
                      _section('Who sees it', Text(d.whoSees, style: body)),
                      _section('How long we keep it', Text(d.keptFor, style: body)),
                      _section('Your rights', Text(d.rights, style: body)),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.gutter, 8, AppDimensions.gutter, 16),
              child: Column(children: [
                InkWell(
                  onTap: () => setState(() => _ticked = !_ticked),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Row(children: [
                    Checkbox(value: _ticked, onChanged: (v) => setState(() => _ticked = v ?? false)),
                    Expanded(child: Text(d.agreeLabel, style: AppTextStyles.bodyMedium)),
                  ]),
                ),
                const SizedBox(height: 8),
                KdButton(label: 'Continue', onPressed: _ticked ? widget.onAgree : null),
                const SizedBox(height: 8),
                KdButton.secondary(label: 'Not now', onPressed: widget.onDecline ?? () => Navigator.of(context).maybePop()),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
