import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Opens a brand-v1 bottom sheet: rounded top, drag handle, dimmed backdrop,
/// lifts above the keyboard. The sheet content gets [KdSheetBody] spacing.
Future<T?> showKdSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: const Color(0x990D0A16),
    backgroundColor: AppColors.surface1,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// Standard sheet layout: title, a lead line, then content.
class KdSheetBody extends StatelessWidget {
  final String title;
  final String? lead;
  final List<Widget> children;

  const KdSheetBody({super.key, required this.title, this.lead, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTextStyles.h3),
          if (lead != null) ...[
            const SizedBox(height: 4),
            Text(lead!, style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
          ],
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}
