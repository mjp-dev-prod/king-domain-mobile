/// Mirrors king-domain-backend's TalentProfile + ProofItem API shapes
/// (src/user/routes.js's serializeTalentProfile/serializeProofItem).
/// fullName lives on the User record, not here — see AuthState in
/// auth_provider.dart — since a client account has a fullName but no
/// TalentProfile at all.
class TalentProfile {
  final String? id;
  final String headline;
  final String bio;
  final List<String> skillCategories;
  final List<ProofItem> proofItems;

  const TalentProfile({
    this.id,
    this.headline = '',
    this.bio = '',
    this.skillCategories = const [],
    this.proofItems = const [],
  });

  factory TalentProfile.fromJson(Map<String, dynamic> json) {
    return TalentProfile(
      id: json['id'] as String?,
      headline: json['headline'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      skillCategories: (json['skillCategories'] as List?)?.cast<String>() ?? const [],
      proofItems: (json['proofItems'] as List?)
              ?.map((p) => ProofItem.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  bool get isProfileComplete =>
      headline.trim().isNotEmpty && bio.trim().isNotEmpty && skillCategories.isNotEmpty;

  /// Milestone 03: a talent must hold Verified status in a category —
  /// approved by human review, not just "submitted" — before applying to
  /// jobs in it. This is the actual anti-spam gate from Milestone 01, and
  /// is re-checked server-side too (see backend jobsRoutes.js's /apply
  /// route) — this client-side check is for UI gating, not the real gate.
  bool isVerifiedIn(String category) => proofItems.any(
    (p) => p.category == category && p.status == ProofReviewStatus.verified,
  );

  TalentProfile copyWith({
    String? id,
    String? headline,
    String? bio,
    List<String>? skillCategories,
    List<ProofItem>? proofItems,
  }) {
    return TalentProfile(
      id: id ?? this.id,
      headline: headline ?? this.headline,
      bio: bio ?? this.bio,
      skillCategories: skillCategories ?? this.skillCategories,
      proofItems: proofItems ?? this.proofItems,
    );
  }
}

enum ProofReviewStatus { pending, verified }

ProofReviewStatus _proofStatusFromString(String? value) =>
    value == 'verified' ? ProofReviewStatus.verified : ProofReviewStatus.pending;

class ProofItem {
  final String id;
  final String category;
  final String title;
  /// A short-lived signed URL from the backend (proof-items bucket is
  /// private — see backend/src/storage.js), not a local device file path
  /// like the old mock. Re-fetch the profile to get a fresh one once this
  /// expires (5 min server-side).
  final String? fileUrl;
  final ProofReviewStatus status;

  const ProofItem({
    required this.id,
    required this.category,
    required this.title,
    this.fileUrl,
    this.status = ProofReviewStatus.pending,
  });

  factory ProofItem.fromJson(Map<String, dynamic> json) {
    return ProofItem(
      id: json['id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      fileUrl: json['fileUrl'] as String?,
      status: _proofStatusFromString(json['status'] as String?),
    );
  }
}
