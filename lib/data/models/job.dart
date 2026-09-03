/// Local mock shape for the T4-T6 job browsing/apply flow. Not wired to a
/// real backend — domain objects aren't settled until Milestone 06.
class Job {
  final String id;
  final String title;
  final String category;
  final String description;
  final double budget;
  final String clientName;
  final double clientRating;
  final int clientCompletedJobs;
  final DateTime postedAt;
  final JobApplicationStatus applicationStatus;

  const Job({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.budget,
    required this.clientName,
    required this.clientRating,
    required this.clientCompletedJobs,
    required this.postedAt,
    this.applicationStatus = JobApplicationStatus.notApplied,
  });

  Job copyWith({JobApplicationStatus? applicationStatus}) {
    return Job(
      id: id,
      title: title,
      category: category,
      description: description,
      budget: budget,
      clientName: clientName,
      clientRating: clientRating,
      clientCompletedJobs: clientCompletedJobs,
      postedAt: postedAt,
      applicationStatus: applicationStatus ?? this.applicationStatus,
    );
  }
}

enum JobApplicationStatus { notApplied, pending, accepted, rejected }

/// Static mock catalog — one job per skill category used in T2's picker so
/// the gating story in T6 always has a real example to demonstrate.
final List<Job> mockJobs = [
  Job(
    id: 'job-1',
    title: 'Landing page redesign for a campus events app',
    category: 'Design & creative',
    description:
        'Redesign our 5-screen onboarding flow. We have a rough Figma '
        'wireframe — need it turned into a polished, on-brand design '
        'system with dark and light variants.',
    budget: 250,
    clientName: 'Campus Connect',
    clientRating: 4.8,
    clientCompletedJobs: 12,
    postedAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  Job(
    id: 'job-2',
    title: 'Build a Flutter widget for a booking calendar',
    category: 'Software & tech',
    description:
        'Need a reusable calendar widget with date-range selection, '
        'blocked-date support, and a clean API. Ships as a package we '
        'reuse across two apps.',
    budget: 400,
    clientName: 'Dormly',
    clientRating: 4.6,
    clientCompletedJobs: 7,
    postedAt: DateTime.now().subtract(const Duration(hours: 8)),
  ),
  Job(
    id: 'job-3',
    title: 'Proofread and edit a 40-page thesis draft',
    category: 'Writing & content',
    description:
        'Looking for careful line-editing and structural feedback on a '
        'social sciences thesis. APA formatting experience preferred.',
    budget: 120,
    clientName: 'Amara O.',
    clientRating: 5.0,
    clientCompletedJobs: 3,
    postedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Job(
    id: 'job-4',
    title: 'Run a 2-week social media growth sprint',
    category: 'Marketing & growth',
    description:
        'New campus marketplace launching soon — need someone to plan '
        'and execute a short growth sprint across Instagram and TikTok.',
    budget: 300,
    clientName: 'King Domain Labs',
    clientRating: 4.9,
    clientCompletedJobs: 20,
    postedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];
