import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_brand.dart';
import '../../widgets/kit/kd_toast.dart';

/// Opens the public privacy policy in the browser. If the phone can't, say so rather than do nothing.
Future<void> openPrivacyPolicy(BuildContext context) async {
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(AppBrand.privacyUrl), mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    KdToast.show(context, 'Couldn\'t open the privacy policy. Try again in a moment.', kind: ToastKind.error);
  }
}
