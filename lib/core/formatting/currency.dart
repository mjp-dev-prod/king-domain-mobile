import 'package:intl/intl.dart';

/// King Domain prices jobs in Naira (see docs/research/market-validation —
/// the platform targets Nigerian university talent). Formats with the ₦
/// symbol and thousands separators, no decimal places (job budgets are
/// whole-Naira amounts in practice).
final _nairaFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

String formatNaira(num amount) => _nairaFormat.format(amount);

final _dollarFormat = NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 0);

/// A price in the job's own currency: naira as ₦, dollars as $ (D37). Always the job's currency, never converted here.
String formatMoney(num amount, String currency) => currency == 'USD' ? _dollarFormat.format(amount) : _nairaFormat.format(amount);
