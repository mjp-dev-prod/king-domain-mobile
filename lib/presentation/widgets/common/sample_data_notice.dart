import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/api_client.dart';

/// Where a screen's data comes from. A store backed by the real API is live;
/// a store standing in for an endpoint that isn't built yet is sample
/// (docs/core/sample-data.md).
enum DataSource { live, sample }

/// Sample stores may only be used against a non-production server. Release
/// builds against production never see sample data.
bool get sampleDataAllowed => nonProductionApiHost != null;

/// The strip every screen shows while its data is a sample, so nobody mistakes
/// it for real behaviour.
class SampleDataNotice extends StatelessWidget {
  final DataSource source;
  final String what;

  const SampleDataNotice({super.key, required this.source, required this.what});

  @override
  Widget build(BuildContext context) {
    if (source == DataSource.live) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: "Sample data. $what isn't connected to the server yet.",
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.warnSoft, borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, size: 18, color: AppColors.warn),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sample data', style: AppTextStyles.title.copyWith(color: AppColors.warn, fontSize: 13)),
                  Text("$what isn't connected to the server yet. Nothing here is real.", style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
