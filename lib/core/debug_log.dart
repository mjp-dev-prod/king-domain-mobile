import 'package:flutter/foundation.dart';

/// One line to the debug console, tagged so it can be filtered (`flutter run` output, or `adb logcat | grep "\[api\]"`).
/// Release builds print nothing, so nothing here can leak to a user's phone log.
///
/// Log the state that DECIDES the outcome (the server's status and body, the size R2 really holds), never just
/// the value that was passed in.
void kdLog(String tag, String message) {
  if (kDebugMode) debugPrint('[$tag] $message');
}
