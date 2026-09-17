import 'package:intl/intl.dart';

/// King Domain prices jobs in Naira (see docs/research/market-validation —
/// the platform targets Nigerian university talent). Formats with the ₦
/// symbol and thousands separators, no decimal places (job budgets are
/// whole-Naira amounts in practice).
final _nairaFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

String formatNaira(num amount) => _nairaFormat.format(amount);
