// Region, education line and identity, as the server describes them (backend src/identity.js and
// src/user/identityRoutes.js; PRD §4.4, decisions D10 to D15).

enum IdentityStatus { notStarted, inReview, notYet, verified }

enum EducationKind { student, graduate, trained, selfTaught }

enum IdentityDocument { ninSlip, passport, cac }

extension EducationKindText on EducationKind {
  String get label => switch (this) {
    EducationKind.student => 'Student',
    EducationKind.graduate => 'Graduate',
    EducationKind.trained => 'Trained',
    EducationKind.selfTaught => 'Self-taught',
  };

  String get schoolHint => switch (this) {
    EducationKind.student || EducationKind.graduate => 'School',
    EducationKind.trained => 'Course or camp',
    EducationKind.selfTaught => '',
  };

  String get detailHint => switch (this) {
    EducationKind.student => 'Session, e.g. 2026/27',
    EducationKind.graduate => 'Year you graduated',
    EducationKind.trained => 'Where, e.g. King Domain camp',
    EducationKind.selfTaught => '',
  };

  bool get needsSchool => this == EducationKind.student || this == EducationKind.graduate;
  bool get needsDetail => this != EducationKind.selfTaught;
}

extension IdentityDocumentText on IdentityDocument {
  String get label => switch (this) {
    IdentityDocument.ninSlip => 'NIN slip',
    IdentityDocument.passport => 'Passport',
    IdentityDocument.cac => 'CAC certificate',
  };

  String get numberLabel => switch (this) {
    IdentityDocument.ninSlip => '11-digit NIN',
    IdentityDocument.passport => 'Passport number',
    IdentityDocument.cac => 'RC number',
  };
}

EducationKind? parseEducationKind(String? v) => EducationKind.values.where((k) => k.name == v).firstOrNull;

class Region {
  final String country;
  final String? state;
  final String? city;
  const Region({required this.country, this.state, this.city});

  factory Region.fromJson(Map<String, dynamic> j) => Region(country: j['country'] as String, state: j['state'] as String?, city: j['city'] as String?);

  String get text => [city, state, country].where((p) => p != null && p.isNotEmpty).join(', ');
}

class EducationLine {
  final EducationKind kind;
  final String? school;
  final String? detail;
  const EducationLine({required this.kind, this.school, this.detail});

  factory EducationLine.fromJson(Map<String, dynamic> j) =>
      EducationLine(kind: parseEducationKind(j['kind'] as String?) ?? EducationKind.selfTaught, school: j['school'] as String?, detail: j['detail'] as String?);

  /// "Student · UNILAG · 2026/27", "Self-taught".
  String get text => [kind.label, school, detail].where((p) => p != null && p.isNotEmpty).join(' · ');
}

class GuardianInfo {
  final String name;
  final String email;
  final bool confirmed;
  const GuardianInfo({required this.name, required this.email, required this.confirmed});

  factory GuardianInfo.fromJson(Map<String, dynamic> j) => GuardianInfo(name: j['name'] as String, email: j['email'] as String, confirmed: j['confirmed'] as bool);
}

class IdentityReason {
  final String? code;
  final String? label;
  final String? note;
  const IdentityReason({this.code, this.label, this.note});

  factory IdentityReason.fromJson(Map<String, dynamic> j) => IdentityReason(code: j['code'] as String?, label: j['label'] as String?, note: j['note'] as String?);
}

class IdentitySummary {
  final IdentityStatus status;
  final bool minor;
  final bool guardianNeeded;
  final bool canTransact;
  final bool requiredForPaidActions;
  final IdentityReason? reason;
  final DateTime? submittedAt;
  final GuardianInfo? guardian;

  const IdentitySummary({
    required this.status,
    required this.minor,
    required this.guardianNeeded,
    required this.canTransact,
    required this.requiredForPaidActions,
    this.reason,
    this.submittedAt,
    this.guardian,
  });

  static IdentityStatus _status(String? v) => switch (v) {
    'inReview' => IdentityStatus.inReview,
    'notYet' => IdentityStatus.notYet,
    'verified' => IdentityStatus.verified,
    _ => IdentityStatus.notStarted,
  };

  factory IdentitySummary.fromJson(Map<String, dynamic> j) {
    final latest = j['latest'] as Map<String, dynamic>?;
    return IdentitySummary(
      status: _status(j['status'] as String?),
      minor: j['minor'] as bool? ?? false,
      guardianNeeded: j['guardianNeeded'] as bool? ?? false,
      canTransact: j['canTransact'] as bool? ?? false,
      requiredForPaidActions: j['requiredForPaidActions'] as bool? ?? false,
      reason: j['reason'] == null ? null : IdentityReason.fromJson(j['reason'] as Map<String, dynamic>),
      submittedAt: latest == null ? null : DateTime.tryParse(latest['submittedAt'] as String? ?? ''),
      guardian: j['guardian'] == null ? null : GuardianInfo.fromJson(j['guardian'] as Map<String, dynamic>),
    );
  }
}
