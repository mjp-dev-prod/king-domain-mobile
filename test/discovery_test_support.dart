import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/data/models/skill.dart';
import 'package:king_domain/data/models/skill_submission.dart';
import 'package:king_domain/presentation/providers/discovery_provider.dart';
import 'package:king_domain/presentation/providers/skill_submissions_provider.dart';
import 'package:king_domain/presentation/providers/skills_provider.dart';
import 'package:king_domain/data/models/discovery.dart';

/// A feed that answers with the jobs it is given, so a screen test never calls the server.
class FakeFeed extends FeedNotifier {
  final List<Job> jobs;
  FakeFeed(this.jobs);

  @override
  Future<FeedState> build() async => FeedState(jobs: jobs, nextCursor: null);
}

SkillCatalog testCatalog() => const SkillCatalog(
  categories: [SkillCategory(key: 'design', label: 'Design & creative'), SkillCategory(key: 'tech', label: 'Software & tech')],
  skills: [
    Skill(key: 'graphic-design', label: 'Graphic design', categoryKey: 'design', open: true, startProof: []),
    Skill(key: 'web-development', label: 'Web development', categoryKey: 'tech', open: true, startProof: []),
  ],
);

/// Everything the job feed, job detail and talent tabs read from the server, answered with nothing in it. Pass
/// [feed] for the jobs the feed should show.
List<Override> discoveryStubs({List<Job> feed = const [], SkillHub? hub}) => [
  feedProvider.overrideWith(() => FakeFeed(feed)),
  skillCatalogProvider.overrideWith((ref) async => testCatalog()),
  skillHubProvider.overrideWith((ref) async => hub ?? const SkillHub(skills: [], uploadsAvailable: true)),
  invitationsProvider.overrideWith((ref) async => const []),
  shortlistAsksProvider.overrideWith((ref) async => const []),
  savedSearchesProvider.overrideWith((ref) async => const <SavedSearch>[]),
  savedTalentsProvider.overrideWith((ref) async => const <TalentCard>[]),
];
