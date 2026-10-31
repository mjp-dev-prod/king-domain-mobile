/// The four job types (decision D1) and the steps each shows (PRD §4.1).
/// Milestone, monthly and hourly steps repeat per unit; the stepper shows one unit.
enum JobKind { oneDelivery, milestones, monthly, hourly }

List<String> lifecycleLabels(JobKind kind) => switch (kind) {
  JobKind.oneDelivery => const ['Agreed', 'Funded', 'Start proof', 'Working', 'Delivered', 'Review', 'Approved', 'Paid'],
  JobKind.milestones => const ['Funded', 'Working', 'Delivered', 'Review', 'Paid'],
  JobKind.monthly => const ['Month funded', 'Working', "Month's deliveries", 'Review', 'Paid'],
  JobKind.hourly => const ['Week funded', 'Hours reported', 'Approve or dispute', 'Paid'],
};
