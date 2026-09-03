import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/talent_profile.dart';

class TalentProfileNotifier extends Notifier<TalentProfile> {
  @override
  TalentProfile build() => const TalentProfile();

  void updateBasics({String? fullName, String? headline, String? bio}) {
    state = state.copyWith(fullName: fullName, headline: headline, bio: bio);
  }

  void setSkillCategories(List<String> categories) {
    state = state.copyWith(skillCategories: categories);
  }

  void addProofItem(ProofItem item) {
    state = state.copyWith(proofItems: [...state.proofItems, item]);
  }

  void removeProofItem(String id) {
    state = state.copyWith(
      proofItems: state.proofItems.where((p) => p.id != id).toList(),
    );
  }

  /// There's no reviewer-facing screen yet, so this simulates a King Domain
  /// reviewer approving a submission — the only way to reach the "verified,
  /// can apply" state in this mock. Real approval happens on the admin side
  /// once that flow exists (out of scope for the talent app).
  void simulateReviewApproval(String proofItemId) {
    state = state.copyWith(
      proofItems: [
        for (final item in state.proofItems)
          if (item.id == proofItemId)
            ProofItem(
              id: item.id,
              category: item.category,
              title: item.title,
              filePath: item.filePath,
              status: ProofReviewStatus.verified,
            )
          else
            item,
      ],
    );
  }
}

final talentProfileProvider =
    NotifierProvider<TalentProfileNotifier, TalentProfile>(
      TalentProfileNotifier.new,
    );
