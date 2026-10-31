import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/data/models/skill.dart';

const _json = {
  'categories': [
    {'key': 'design', 'label': 'Design & creative'},
    {'key': 'video', 'label': 'Video & media'},
  ],
  'skills': [
    {
      'key': 'graphic-design', 'label': 'Graphic design', 'category': 'design', 'open': true,
      'startProof': [
        {'key': 'concepts', 'label': 'Two or three concept directions', 'kind': 'files', 'min': 2, 'max': 3},
      ],
    },
    {
      'key': 'short-form-video', 'label': 'Short-form video editing', 'category': 'video', 'open': true,
      'startProof': [
        {'key': 'roughCut', 'label': 'Rough cut of the first piece', 'kind': 'video', 'min': 1, 'max': 1},
      ],
    },
  ],
};

void main() {
  test('parses categories, skills and start-proof fields', () {
    final c = SkillCatalog.fromJson(_json);
    expect(c.categories.map((x) => x.label), ['Design & creative', 'Video & media']);
    final video = c.byKey('short-form-video')!;
    expect(video.startProof.single.kind, ProofFieldKind.video);
    expect(video.startProof.single.min, 1);
    expect(c.categoryLabel('video'), 'Video & media');
  });

  test('openIn lists only open skills in a category; unknown keys give null', () {
    final c = SkillCatalog.fromJson(_json);
    expect(c.openIn('design').map((s) => s.key), ['graphic-design']);
    expect(c.byKey('nope'), isNull);
  });

  test('an unknown proof kind fails loudly instead of guessing', () {
    expect(
      () => StartProofField.fromJson({'key': 'k', 'label': 'l', 'kind': 'hologram', 'min': 1, 'max': 1}),
      throwsA(isA<FormatException>()),
    );
  });
}
