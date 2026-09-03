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
}

final talentProfileProvider =
    NotifierProvider<TalentProfileNotifier, TalentProfile>(
      TalentProfileNotifier.new,
    );
