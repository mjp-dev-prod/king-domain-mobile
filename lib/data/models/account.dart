/// A contract that is not finished, as the server lists it when it refuses to delete an account.
/// [role] is the person's own side of it: 'client' or 'talent'.
class ActiveContract {
  final String jobId;
  final String title;
  final String role;
  final String status;
  const ActiveContract({required this.jobId, required this.title, required this.role, required this.status});

  factory ActiveContract.fromJson(Map<String, dynamic> json) => ActiveContract(
        jobId: json['jobId'] as String,
        title: json['title'] as String,
        role: json['role'] as String,
        status: json['status'] as String,
      );

  /// The `contracts` list of a refusal's body; empty when there is none or it is not a list.
  static List<ActiveContract> listFrom(Map<String, dynamic>? body) {
    final raw = body?['contracts'];
    if (raw is! List) return const [];
    return [for (final item in raw) if (item is Map<String, dynamic>) ActiveContract.fromJson(item)];
  }
}
