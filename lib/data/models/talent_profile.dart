/// Local, in-memory shape for the T2 Profile Builder / T3 Proof Upload mock
/// flow. Deliberately not wired to a real backend yet — see
/// docs/features (mobile app build is pre-Milestone-06 domain modelling).
class TalentProfile {
  final String fullName;
  final String headline;
  final String bio;
  final List<String> skillCategories;
  final List<ProofItem> proofItems;

  const TalentProfile({
    this.fullName = '',
    this.headline = '',
    this.bio = '',
    this.skillCategories = const [],
    this.proofItems = const [],
  });

  bool get isProfileComplete =>
      fullName.trim().isNotEmpty &&
      headline.trim().isNotEmpty &&
      bio.trim().isNotEmpty &&
      skillCategories.isNotEmpty;

  TalentProfile copyWith({
    String? fullName,
    String? headline,
    String? bio,
    List<String>? skillCategories,
    List<ProofItem>? proofItems,
  }) {
    return TalentProfile(
      fullName: fullName ?? this.fullName,
      headline: headline ?? this.headline,
      bio: bio ?? this.bio,
      skillCategories: skillCategories ?? this.skillCategories,
      proofItems: proofItems ?? this.proofItems,
    );
  }
}

enum ProofReviewStatus { pending, verified }

class ProofItem {
  final String id;
  final String category;
  final String title;
  final String? filePath;
  final ProofReviewStatus status;

  const ProofItem({
    required this.id,
    required this.category,
    required this.title,
    this.filePath,
    this.status = ProofReviewStatus.pending,
  });
}
