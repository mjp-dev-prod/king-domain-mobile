import 'package:intl/intl.dart';

final _deadlineFormat = DateFormat('EEE d MMM, h:mm a');

/// "Fri 2 Oct, 3:34 PM", in the phone's own clock (the backend stores UTC).
String formatDeadline(DateTime deadline) => _deadlineFormat.format(deadline.toLocal());

/// How long until [deadline], in the two most useful units: "23h 58m",
/// "2 days 4h", "12 min". Past or within a minute: "less than a minute".
/// Returns null once the deadline has passed, so callers can switch wording.
String? timeLeft(DateTime deadline, {DateTime? now}) {
  final remaining = deadline.difference(now ?? DateTime.now());
  if (remaining.isNegative) return null;
  if (remaining.inMinutes < 1) return 'less than a minute';
  if (remaining.inHours < 1) return '${remaining.inMinutes} min';
  if (remaining.inHours < 24) return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  return '$days day${days == 1 ? '' : 's'} ${hours}h';
}
