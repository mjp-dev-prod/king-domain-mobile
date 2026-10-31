import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

enum KdStepState { done, current, waiting, later }

class KdStep {
  final String label;
  final String? subtitle;
  final KdStepState state;
  const KdStep({required this.label, required this.state, this.subtitle});
}

/// A vertical stepper on a thin rail, for any job type (PRD §4.1). Green only
/// for done, violet for the step you act on, amber when it waits on someone.
class KdStepper extends StatelessWidget {
  final List<KdStep> steps;
  const KdStepper({super.key, required this.steps});

  static String _spoken(KdStepState s) => switch (s) {
    KdStepState.done => 'done',
    KdStepState.current => 'your turn',
    KdStepState.waiting => 'waiting on someone',
    KdStepState.later => 'later',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            label: 'Step ${i + 1} of ${steps.length}: ${steps[i].label}, ${_spoken(steps[i].state)}',
            excludeSemantics: true,
            child: _Row(step: steps[i], first: i == 0, last: i == steps.length - 1, railDone: steps[i].state == KdStepState.done),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final KdStep step;
  final bool first;
  final bool last;
  final bool railDone;
  const _Row({required this.step, required this.first, required this.last, required this.railDone});

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (step.state) {
      KdStepState.done => (AppColors.okSoft, AppColors.ok),
      KdStepState.current => (AppColors.primarySoft, AppColors.primaryText),
      KdStepState.waiting => (AppColors.warnSoft, AppColors.warn),
      KdStepState.later => (AppColors.surface2, AppColors.text3),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(width: 2, height: 8, color: first ? Colors.transparent : AppColors.surface3),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                  child: step.state == KdStepState.done
                      ? Icon(Icons.check_rounded, size: 16, color: ink)
                      : Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: ink, shape: BoxShape.circle))),
                ),
                Expanded(child: Container(width: 2, color: last ? Colors.transparent : (railDone ? AppColors.ok : AppColors.surface3))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label, style: AppTextStyles.title.copyWith(color: step.state == KdStepState.later ? AppColors.text3 : AppColors.text)),
                  if (step.subtitle != null) Text(step.subtitle!, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
