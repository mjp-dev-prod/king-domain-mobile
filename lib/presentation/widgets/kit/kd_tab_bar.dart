import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_motion.dart';
import '../../../core/constants/app_text_styles.dart';

class KdTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  /// A count shown on the tab (e.g. contracts needing you); null or 0 hides it.
  final int? badge;
  const KdTab({required this.icon, required this.activeIcon, required this.label, this.badge});
}

/// The floating tab bar from the prototypes: a raised surface with a soft
/// shadow (it floats, so it may have one), and a violet-soft pill that slides
/// to the selected tab with a spring.
class KdTabBar extends StatelessWidget {
  final List<KdTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  const KdTabBar({super.key, required this.tabs, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom : 14),
      child: Container(
        height: 66,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 34, offset: Offset(0, 14))],
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth / tabs.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: reduce ? Duration.zero : AppMotion.layout,
                  curve: AppMotion.spring,
                  left: w * index,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18))),
                ),
                Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Expanded(
                        child: Semantics(
                          selected: i == index,
                          button: true,
                          label: tabs[i].label,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (i != index) HapticFeedback.selectionClick();
                              onChanged(i);
                            },
                            child: ExcludeSemantics(child: _TabItem(tab: tabs[i], selected: i == index)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final KdTab tab;
  final bool selected;
  const _TabItem({required this.tab, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryText : AppColors.text3;
    final badge = tab.badge ?? 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(selected ? tab.activeIcon : tab.icon, color: color, size: 22),
            if (badge > 0)
              Positioned(
                top: -5,
                right: -10,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('$badge', style: AppTextStyles.hint.copyWith(color: AppColors.onPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(tab.label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
