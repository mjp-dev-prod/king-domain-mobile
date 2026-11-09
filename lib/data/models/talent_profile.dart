/// Mirrors king-domain-backend's TalentProfile API shape (src/user/routes.js's serializeTalentProfile). The old
/// proof-of-work items were retired on 2026-11-09: being verified is a skill submission now (skill_submission.dart).
/// fullName lives on the User record, not here — see AuthState in
/// auth_provider.dart — since a client account has a fullName but no
/// TalentProfile at all.
class TalentProfile {
  final String? id;
  final String headline;
  final String bio;
  final List<String> skillCategories;
  /// Where approved-job payments are sent. Null until the talent adds one.
  final PayoutAccount? payoutAccount;

  const TalentProfile({
    this.id,
    this.headline = '',
    this.bio = '',
    this.skillCategories = const [],
    this.payoutAccount,
  });

  factory TalentProfile.fromJson(Map<String, dynamic> json) {
    final bank = json['bankAccount'] as Map<String, dynamic>?;
    return TalentProfile(
      payoutAccount: bank != null ? PayoutAccount.fromJson(bank) : null,
      id: json['id'] as String?,
      headline: json['headline'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      skillCategories: (json['skillCategories'] as List?)?.cast<String>() ?? const [],
    );
  }

  bool get isProfileComplete =>
      headline.trim().isNotEmpty && bio.trim().isNotEmpty && skillCategories.isNotEmpty;

  TalentProfile copyWith({
    String? id,
    String? headline,
    String? bio,
    List<String>? skillCategories,
  }) {
    return TalentProfile(
      id: id ?? this.id,
      headline: headline ?? this.headline,
      bio: bio ?? this.bio,
      skillCategories: skillCategories ?? this.skillCategories,
      payoutAccount: payoutAccount,
    );
  }
}

/// Masked server-side (backend routes.js serializeTalentProfile) — the full
/// account number and Paystack recipient code never reach the app.
class PayoutAccount {
  final String? bankName;
  final String accountName;
  final String accountNumberLast4;

  const PayoutAccount({this.bankName, required this.accountName, required this.accountNumberLast4});

  factory PayoutAccount.fromJson(Map<String, dynamic> json) => PayoutAccount(
    bankName: json['bankName'] as String?,
    accountName: json['accountName'] as String? ?? '',
    accountNumberLast4: json['accountNumberLast4'] as String? ?? '',
  );
}

class Bank {
  final String name;
  final String code;

  const Bank({required this.name, required this.code});

  factory Bank.fromJson(Map<String, dynamic> json) =>
      Bank(name: json['name'] as String, code: json['code'] as String);
}

