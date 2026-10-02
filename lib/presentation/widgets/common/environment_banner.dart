import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// A thin strip above the whole app while it talks to a server other than
/// production, so a staging run is never mistaken for the real thing. With a
/// null [host] (every normal and release build) it adds nothing.
///
/// The strip takes over the status-bar inset, so the screens below it drop
/// theirs instead of leaving a double gap.
class EnvironmentBanner extends StatelessWidget {
  final String? host;
  final Widget child;

  const EnvironmentBanner({super.key, required this.host, required this.child});

  @override
  Widget build(BuildContext context) {
    final host = this.host;
    if (host == null) return child;

    return Column(
      children: [
        Material(
          color: AppColors.warn,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 22,
              width: double.infinity,
              child: Center(
                child: Text(
                  'TEST SERVER · $host',
                  style: AppTextStyles.label.copyWith(color: AppColors.ground, fontSize: 10, letterSpacing: 1),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}
