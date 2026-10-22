import '../../../data/models/job.dart';

/// How the job feed is ordered.
enum FeedSort { newest, budgetHigh, budgetLow, fastest }

extension FeedSortLabel on FeedSort {
  String get label => switch (this) {
    FeedSort.newest => 'Newest',
    FeedSort.budgetHigh => 'Highest budget',
    FeedSort.budgetLow => 'Lowest budget',
    FeedSort.fastest => 'Fastest delivery',
  };
}

/// The jobs to show, after a search, the "can apply" switch and a sort. Pure: it never changes
/// the list it is given.
///
/// Search: every word must appear somewhere in the title, category, description or client name,
/// in any order, ignoring case and extra spaces.
/// [canApplyOnly] keeps jobs for which [canApply] says yes; with no [canApply] it keeps none
/// rather than pretending it knows.
/// Ties always fall back to newest, then to the id, so the order never flickers.
List<Job> filterAndSortJobs(
  List<Job> jobs, {
  String query = '',
  FeedSort sort = FeedSort.newest,
  bool canApplyOnly = false,
  bool Function(Job job)? canApply,
}) {
  final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  bool matches(Job j) {
    if (terms.isEmpty) return true;
    final haystack = '${j.title} ${j.category} ${j.description} ${j.clientName}'.toLowerCase();
    return terms.every(haystack.contains);
  }

  final kept = jobs.where((j) => matches(j) && (!canApplyOnly || (canApply?.call(j) ?? false))).toList();

  int byNewest(Job a, Job b) {
    final r = b.postedAt.compareTo(a.postedAt);
    return r != 0 ? r : a.id.compareTo(b.id);
  }

  int primary(Job a, Job b) => switch (sort) {
    FeedSort.newest => 0,
    FeedSort.budgetHigh => b.budget.compareTo(a.budget),
    FeedSort.budgetLow => a.budget.compareTo(b.budget),
    FeedSort.fastest => (a.deliveryDays ?? 1 << 30).compareTo(b.deliveryDays ?? 1 << 30),
  };

  kept.sort((a, b) {
    final r = primary(a, b);
    return r != 0 ? r : byNewest(a, b);
  });
  return kept;
}
