// Mirrors king-domain-backend's src/packages.js, src/premium.js and src/questions.js (PRD §4.6, §4.10; D4, D28, D38, D39).
import 'discovery.dart' show BriefField;
import 'reputation.dart';

DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
List<Map<String, dynamic>> _maps(Object? v) => [for (final e in (v as List? ?? const [])) e as Map<String, dynamic>];

class PackageTalent {
  final String id;
  final String fullName;
  final String? photoUrl;
  final String lastActive;
  const PackageTalent({required this.id, required this.fullName, this.photoUrl, required this.lastActive});

  factory PackageTalent.fromJson(Map<String, dynamic> j) => PackageTalent(id: j['id'] as String, fullName: j['fullName'] as String, photoUrl: j['photoUrl'] as String?, lastActive: j['lastActive'] as String? ?? 'earlier');

  String get lastActiveText => switch (lastActive) { 'today' => 'Active today', 'this_week' => 'Active this week', 'this_month' => 'Active this month', _ => 'Active a while ago' };
}

class PackageItem {
  final String id;
  final String skillKey;
  final String skillLabel;
  final String tier;
  final String title;
  final String summary;
  final double price;
  final String currency;
  final int deliveryDays;
  final int revisions;
  final String included;
  final int quantity;
  final String formats;
  final String status;
  final PackageTalent? talent;
  const PackageItem({
    required this.id,
    required this.skillKey,
    required this.skillLabel,
    required this.tier,
    required this.title,
    required this.summary,
    required this.price,
    required this.currency,
    required this.deliveryDays,
    required this.revisions,
    required this.included,
    required this.quantity,
    required this.formats,
    required this.status,
    this.talent,
  });

  bool get paused => status == 'paused';
  String get tierLabel => switch (tier) { 'basic' => 'Basic', 'standard' => 'Standard', _ => 'Premium' };

  factory PackageItem.fromJson(Map<String, dynamic> j) => PackageItem(
    id: j['id'] as String,
    skillKey: j['skillKey'] as String,
    skillLabel: j['skillLabel'] as String? ?? j['skillKey'] as String,
    tier: j['tier'] as String,
    title: j['title'] as String,
    summary: j['summary'] as String? ?? '',
    price: (j['price'] as num).toDouble(),
    currency: j['currency'] as String? ?? 'NGN',
    deliveryDays: (j['deliveryDays'] as num).toInt(),
    revisions: (j['revisions'] as num).toInt(),
    included: j['included'] as String? ?? '',
    quantity: (j['quantity'] as num).toInt(),
    formats: j['formats'] as String? ?? '',
    status: j['status'] as String? ?? 'active',
    talent: j['talent'] == null ? null : PackageTalent.fromJson(j['talent'] as Map<String, dynamic>),
  );
}

/// A talent's own packages, and the skills they may publish in (those they are verified in).
class MyPackages {
  final List<PackageItem> packages;
  final List<({String skillKey, String label})> skills;
  final List<String> tiers;
  const MyPackages({required this.packages, required this.skills, required this.tiers});

  factory MyPackages.fromJson(Map<String, dynamic> j) => MyPackages(
    packages: [for (final p in _maps(j['packages'])) PackageItem.fromJson(p)],
    skills: [for (final s in _maps(j['skills'])) (skillKey: s['skillKey'] as String, label: s['label'] as String)],
    tiers: [for (final t in (j['tiers'] as List? ?? const ['basic', 'standard', 'premium'])) t as String],
  );

  PackageItem? at(String skillKey, String tier) => packages.where((p) => p.skillKey == skillKey && p.tier == tier).firstOrNull;
}

class PackagePage {
  final List<PackageItem> packages;
  final String? nextCursor;
  const PackagePage({required this.packages, this.nextCursor});

  factory PackagePage.fromJson(Map<String, dynamic> j) => PackagePage(packages: [for (final p in _maps(j['packages'])) PackageItem.fromJson(p)], nextCursor: j['nextCursor'] as String?);
}

class PackageDetail {
  final PackageItem package;
  final PackageTalent talent;
  /// What the package doesn't already say: the rest of the skill's brief.
  final List<BriefField> formFields;
  final TalentReputation reputation;
  final double fee;
  const PackageDetail({required this.package, required this.talent, required this.formFields, required this.reputation, required this.fee});

  factory PackageDetail.fromJson(Map<String, dynamic> j) => PackageDetail(
    package: PackageItem.fromJson(j['package'] as Map<String, dynamic>),
    talent: PackageTalent.fromJson(j['talent'] as Map<String, dynamic>),
    formFields: [for (final f in _maps(j['formFields'])) BriefField.fromJson(f)],
    reputation: TalentReputation.fromJson(j['reputation'] as Map<String, dynamic>? ?? const {}),
    fee: (j['fee'] as num?)?.toDouble() ?? 0,
  );
}

class PackageOrderItem {
  final String id;
  /// requested, accepted, declined, expired or cancelled.
  final String status;
  final String title;
  final double price;
  final String currency;
  final int? deliveryDays;
  final String? skillLabel;
  final String other;
  final String? jobId;
  final String note;
  final DateTime answerDueAt;
  final DateTime createdAt;
  const PackageOrderItem({required this.id, required this.status, required this.title, required this.price, required this.currency, this.deliveryDays, this.skillLabel, required this.other, this.jobId, required this.note, required this.answerDueAt, required this.createdAt});

  bool get waiting => status == 'requested';

  factory PackageOrderItem.fromJson(Map<String, dynamic> j) => PackageOrderItem(
    id: j['id'] as String,
    status: j['status'] as String,
    title: j['title'] as String? ?? 'Package',
    price: (j['price'] as num?)?.toDouble() ?? 0,
    currency: j['currency'] as String? ?? 'NGN',
    deliveryDays: (j['deliveryDays'] as num?)?.toInt(),
    skillLabel: j['skillLabel'] as String?,
    other: j['other'] as String? ?? 'Someone',
    jobId: j['jobId'] as String?,
    note: j['note'] as String? ?? '',
    answerDueAt: _date(j['answerDueAt']) ?? DateTime.now(),
    createdAt: _date(j['createdAt']) ?? DateTime.now(),
  );
}

class PremiumFeature {
  /// reopen_job or pre_apply_question.
  final String feature;
  final String label;
  final String? productId;
  /// Purchases bought and not yet used.
  final int credits;
  const PremiumFeature({required this.feature, required this.label, this.productId, this.credits = 0});

  factory PremiumFeature.fromJson(Map<String, dynamic> j) => PremiumFeature(feature: j['feature'] as String, label: j['label'] as String, productId: j['productId'] as String?, credits: (j['credits'] as num?)?.toInt() ?? 0);
}

class PremiumStatus {
  /// With this off the two features are free (before launch); on, each use costs a Google Play purchase.
  final bool enforced;
  final bool billingConfigured;
  final List<PremiumFeature> features;
  final String rule;
  const PremiumStatus({required this.enforced, required this.billingConfigured, required this.features, required this.rule});

  PremiumFeature? of(String feature) => features.where((f) => f.feature == feature).firstOrNull;

  factory PremiumStatus.fromJson(Map<String, dynamic> j) => PremiumStatus(
    enforced: j['enforced'] as bool? ?? false,
    billingConfigured: j['billingConfigured'] as bool? ?? false,
    features: [for (final f in _maps(j['features'])) PremiumFeature.fromJson(f)],
    rule: j['rule'] as String? ?? '',
  );
}

/// A question to a client before applying, with its answer once the client gives it. Answers are for every applicant.
class JobQuestion {
  final String id;
  final String question;
  final String? answer;
  final bool mine;
  final bool canAnswer;
  final DateTime askedAt;
  const JobQuestion({required this.id, required this.question, this.answer, this.mine = false, this.canAnswer = false, required this.askedAt});

  factory JobQuestion.fromJson(Map<String, dynamic> j) => JobQuestion(
    id: j['id'] as String,
    question: j['question'] as String,
    answer: j['answer'] as String?,
    mine: j['mine'] as bool? ?? false,
    canAnswer: j['canAnswer'] as bool? ?? false,
    askedAt: _date(j['askedAt']) ?? DateTime.now(),
  );
}
