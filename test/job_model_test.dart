import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/data/models/job.dart';

Map<String, dynamic> _json({Map<String, dynamic> extra = const {}}) => {
  'id': 'j1',
  'title': 'Logo',
  'category': 'Design & creative',
  'description': 'd',
  'budget': '45000.00',
  'createdAt': '2026-10-20T10:00:00Z',
  'client': {'id': 'c1', 'fullName': 'Chinedu'},
  ...extra,
};

void main() {
  group('Job closed and revision', () {
    test('parse from the API', () {
      final j = Job.fromJson(_json(extra: {'closedAt': '2026-10-21T08:00:00Z', 'revision': 3}));
      expect(j.closed, isTrue);
      expect(j.closedAt, DateTime.utc(2026, 10, 21, 8));
      expect(j.revision, 3);
    });

    test('default to open and revision 0 when absent (older servers)', () {
      final j = Job.fromJson(_json());
      expect(j.closed, isFalse);
      expect(j.closedAt, isNull);
      expect(j.revision, 0);
    });

    test('copyWith keeps them', () {
      final j = Job.fromJson(_json(extra: {'closedAt': '2026-10-21T08:00:00Z', 'revision': 2}));
      final c = j.copyWith(applicationCount: 4);
      expect(c.closed, isTrue);
      expect(c.revision, 2);
    });
  });

  group('ApiException.fromResponse', () {
    test('reads the message and the machine-readable code', () {
      final e = ApiException.fromResponse(409, '{"error":"This job was just edited.","code":"terms_changed"}');
      expect(e.message, 'This job was just edited.');
      expect(e.status, 409);
      expect(e.code, 'terms_changed');
    });

    test('a body without a code leaves it null, and junk falls back to a plain message', () {
      expect(ApiException.fromResponse(400, '{"error":"title is required."}').code, isNull);
      final junk = ApiException.fromResponse(502, '<html>bad gateway</html>');
      expect(junk.message, 'Something went wrong.');
      expect(junk.code, isNull);
    });
  });
}
