// Mirrors king-domain-backend's src/user/contractExtrasRoutes.js: the start proof, shared drafts, receipts and the
// dollar rate. The server decides what is missing and what may happen next; these classes only carry it.

DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');

class ProofItem {
  final String id;
  final String? text;
  final String? name;
  final String? contentType;
  final int? sizeBytes;
  /// A short-lived link to the file. Null when storage isn't available.
  final String? url;
  const ProofItem({required this.id, this.text, this.name, this.contentType, this.sizeBytes, this.url});

  factory ProofItem.fromJson(Map<String, dynamic> j) => ProofItem(
    id: j['id'] as String,
    text: j['text'] as String?,
    name: j['name'] as String?,
    contentType: j['contentType'] as String?,
    sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
    url: j['url'] as String?,
  );
}

/// One part the skill's start proof asks for. [kind] is files, image, video, text or link.
class ProofField {
  final String key;
  final String label;
  final String kind;
  final int min;
  final int max;
  final List<ProofItem> items;
  const ProofField({required this.key, required this.label, required this.kind, required this.min, required this.max, required this.items});

  bool get isFile => kind == 'files' || kind == 'image' || kind == 'video';
  bool get isTyped => kind == 'text' || kind == 'link';
  bool get done => items.length >= min;
  bool get full => items.length >= max;

  /// "2 or 3", "one", "2".
  String get countWords => min == max ? (min == 1 ? 'one' : '$min') : '$min to $max';

  factory ProofField.fromJson(Map<String, dynamic> j) => ProofField(
    key: j['key'] as String,
    label: j['label'] as String,
    kind: j['kind'] as String,
    min: (j['min'] as num).toInt(),
    max: (j['max'] as num).toInt(),
    items: [for (final i in (j['items'] as List? ?? const [])) ProofItem.fromJson(i as Map<String, dynamic>)],
  );
}

class ProofObjection {
  final String code;
  final String label;
  final String note;
  const ProofObjection({required this.code, required this.label, required this.note});

  factory ProofObjection.fromJson(Map<String, dynamic> j) =>
      ProofObjection(code: j['reasonCode'] as String? ?? '', label: j['label'] as String? ?? '', note: j['note'] as String? ?? '');
}

class ObjectionReason {
  final String code;
  final String label;
  const ObjectionReason(this.code, this.label);
}

/// The start proof on one contract: what is asked for, what is there, and where it stands. [status] is null while
/// nothing has been sent, then submitted, objected, accepted or redo.
class StartProof {
  final bool required;
  final String? status;
  final int round;
  final DateTime? submittedAt;
  final DateTime? dueAt;
  final DateTime? acceptedAt;
  final ProofObjection? objection;
  final double upfrontAmount;
  final DateTime? upfrontPaidAt;
  final List<ProofField> fields;
  final List<String> missing;
  final bool readyToSend;
  final List<ObjectionReason> objectionReasons;
  final bool uploadsAvailable;
  final String currency;

  const StartProof({
    required this.required,
    required this.status,
    required this.round,
    required this.submittedAt,
    required this.dueAt,
    required this.acceptedAt,
    required this.objection,
    required this.upfrontAmount,
    required this.upfrontPaidAt,
    required this.fields,
    required this.missing,
    required this.readyToSend,
    required this.objectionReasons,
    required this.uploadsAvailable,
    required this.currency,
  });

  /// The talent can still add, change and send parts.
  bool get editable => status == null || status == 'redo';

  factory StartProof.fromJson(Map<String, dynamic> json) {
    final j = json['startProof'] as Map<String, dynamic>;
    return StartProof(
      required: j['required'] as bool? ?? false,
      status: j['status'] as String?,
      round: (j['round'] as num?)?.toInt() ?? 0,
      submittedAt: _date(j['submittedAt']),
      dueAt: _date(j['dueAt']),
      acceptedAt: _date(j['acceptedAt']),
      objection: j['objection'] == null ? null : ProofObjection.fromJson(j['objection'] as Map<String, dynamic>),
      upfrontAmount: (j['upfrontAmount'] as num?)?.toDouble() ?? 0,
      upfrontPaidAt: _date(j['upfrontPaidAt']),
      fields: [for (final f in (j['fields'] as List? ?? const [])) ProofField.fromJson(f as Map<String, dynamic>)],
      missing: [for (final m in (j['missing'] as List? ?? const [])) (m as Map<String, dynamic>)['problem'] as String],
      readyToSend: j['readyToSend'] as bool? ?? false,
      objectionReasons: [for (final r in (j['objectionReasons'] as List? ?? const [])) ObjectionReason((r as Map<String, dynamic>)['code'] as String, r['label'] as String)],
      uploadsAvailable: j['uploadsAvailable'] as bool? ?? false,
      currency: j['currency'] as String? ?? 'NGN',
    );
  }
}

class DraftFile {
  final String name;
  final String contentType;
  final int sizeBytes;
  final String? url;
  const DraftFile({required this.name, required this.contentType, required this.sizeBytes, this.url});

  factory DraftFile.fromJson(Map<String, dynamic> j) =>
      DraftFile(name: j['name'] as String, contentType: j['contentType'] as String? ?? '', sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0, url: j['url'] as String?);
}

/// Work in progress the talent showed, dated. It never starts the review clock.
class DraftShare {
  final String id;
  final String note;
  final DateTime createdAt;
  final List<DraftFile> files;
  const DraftShare({required this.id, required this.note, required this.createdAt, required this.files});

  factory DraftShare.fromJson(Map<String, dynamic> j) => DraftShare(
    id: j['id'] as String,
    note: j['note'] as String? ?? '',
    createdAt: _date(j['createdAt']) ?? DateTime.now(),
    files: [for (final f in (j['files'] as List? ?? const [])) DraftFile.fromJson(f as Map<String, dynamic>)],
  );
}

class DraftList {
  final List<DraftShare> drafts;
  final bool uploadsAvailable;
  const DraftList({required this.drafts, required this.uploadsAvailable});

  factory DraftList.fromJson(Map<String, dynamic> j) => DraftList(
    drafts: [for (final d in (j['drafts'] as List? ?? const [])) DraftShare.fromJson(d as Map<String, dynamic>)],
    uploadsAvailable: j['uploadsAvailable'] as bool? ?? false,
  );
}

class Payout {
  final double amount;
  final DateTime? paidAt;
  final String? reference;
  const Payout({required this.amount, this.paidAt, this.reference});

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(amount: (j['amount'] as num).toDouble(), paidAt: _date(j['paidAt']), reference: j['reference'] as String?);
}

/// What Paystack asks for when a payment is questioned: who paid, how much, when, for what.
class Receipt {
  final String viewer;
  final String jobTitle;
  final String service;
  final String currency;
  final double price;
  final double platformFee;
  final double totalPaidByClient;
  final DateTime? paidAt;
  final String? reference;
  final String clientName;
  final String? talentName;
  final String status;
  final Payout? upfront;
  final Payout? finalPayout;
  final bool hasPayouts;

  const Receipt({
    required this.viewer,
    required this.jobTitle,
    required this.service,
    required this.currency,
    required this.price,
    required this.platformFee,
    required this.totalPaidByClient,
    required this.paidAt,
    required this.reference,
    required this.clientName,
    required this.talentName,
    required this.status,
    required this.upfront,
    required this.finalPayout,
    required this.hasPayouts,
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final r = json['receipt'] as Map<String, dynamic>;
    final payouts = r['payouts'] as Map<String, dynamic>?;
    return Receipt(
      viewer: json['viewer'] as String? ?? 'client',
      jobTitle: r['jobTitle'] as String,
      service: r['service'] as String? ?? r['jobTitle'] as String,
      currency: r['currency'] as String? ?? 'NGN',
      price: (r['price'] as num).toDouble(),
      platformFee: (r['platformFee'] as num?)?.toDouble() ?? 0,
      totalPaidByClient: (r['totalPaidByClient'] as num).toDouble(),
      paidAt: _date(r['paidAt']),
      reference: r['reference'] as String?,
      clientName: (r['client'] as Map<String, dynamic>?)?['name'] as String? ?? 'Client',
      talentName: (r['talent'] as Map<String, dynamic>?)?['name'] as String?,
      status: r['status'] as String? ?? '',
      upfront: payouts?['upfront'] == null ? null : Payout.fromJson(payouts!['upfront'] as Map<String, dynamic>),
      finalPayout: payouts?['final'] == null ? null : Payout.fromJson(payouts!['final'] as Map<String, dynamic>),
      hasPayouts: payouts != null,
    );
  }
}

/// Which job types and currencies can be paid for today. Missing or failed to load means "assume yes": the server
/// refuses with a plain reason either way.
class Availability {
  final Map<String, bool> jobTypes;
  final bool usd;
  const Availability({this.jobTypes = const {}, this.usd = true});

  bool type(String name) => jobTypes[name] ?? true;

  factory Availability.fromJson(Map<String, dynamic> j) => Availability(
    jobTypes: {for (final e in ((j['jobTypes'] as Map?) ?? const {}).entries) e.key as String: e.value as bool},
    usd: j['usd'] as bool? ?? true,
  );
}

/// The naira per dollar rate the team set, when it was set. [ngnPerUsd] is null when none is set: nothing is converted.
class FxRate {
  final double? ngnPerUsd;
  final DateTime? asOf;
  const FxRate({this.ngnPerUsd, this.asOf});

  factory FxRate.fromJson(Map<String, dynamic> j) => FxRate(ngnPerUsd: (j['ngnPerUsd'] as num?)?.toDouble(), asOf: _date(j['asOf']));
}
