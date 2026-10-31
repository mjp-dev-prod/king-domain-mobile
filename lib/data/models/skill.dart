/// The skills King Domain verifies and hires for, as served by GET /skills
/// (backend src/skills.js; PRD §4.2 and decision D25).
enum ProofFieldKind { files, image, video, text, link }

class StartProofField {
  final String key;
  final String label;
  final ProofFieldKind kind;
  final int min;
  final int max;

  const StartProofField({required this.key, required this.label, required this.kind, required this.min, required this.max});

  factory StartProofField.fromJson(Map<String, dynamic> j) {
    final kind = ProofFieldKind.values.where((k) => k.name == j['kind']).firstOrNull;
    if (kind == null) throw FormatException('Unknown start-proof kind "${j['kind']}"');
    return StartProofField(key: j['key'] as String, label: j['label'] as String, kind: kind, min: j['min'] as int, max: j['max'] as int);
  }
}

class Skill {
  final String key;
  final String label;
  final String categoryKey;
  final bool open;
  final List<StartProofField> startProof;

  const Skill({required this.key, required this.label, required this.categoryKey, required this.open, required this.startProof});

  factory Skill.fromJson(Map<String, dynamic> j) => Skill(
    key: j['key'] as String,
    label: j['label'] as String,
    categoryKey: j['category'] as String,
    open: j['open'] as bool,
    startProof: [for (final f in j['startProof'] as List) StartProofField.fromJson(f as Map<String, dynamic>)],
  );
}

class SkillCategory {
  final String key;
  final String label;
  const SkillCategory({required this.key, required this.label});
  factory SkillCategory.fromJson(Map<String, dynamic> j) => SkillCategory(key: j['key'] as String, label: j['label'] as String);
}

class SkillCatalog {
  final List<SkillCategory> categories;
  final List<Skill> skills;

  const SkillCatalog({required this.categories, required this.skills});

  factory SkillCatalog.fromJson(Map<String, dynamic> j) => SkillCatalog(
    categories: [for (final c in j['categories'] as List) SkillCategory.fromJson(c as Map<String, dynamic>)],
    skills: [for (final s in j['skills'] as List) Skill.fromJson(s as Map<String, dynamic>)],
  );

  Skill? byKey(String key) => skills.where((s) => s.key == key).firstOrNull;

  List<Skill> openIn(String categoryKey) => [for (final s in skills) if (s.open && s.categoryKey == categoryKey) s];

  String categoryLabel(String key) => categories.firstWhere((c) => c.key == key, orElse: () => SkillCategory(key: key, label: key)).label;
}
