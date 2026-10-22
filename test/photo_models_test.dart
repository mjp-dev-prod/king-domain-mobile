import 'package:flutter_test/flutter_test.dart';
import 'package:king_domain/data/models/job.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';

/// Profile photos reach the app as a permanent public link (`photoUrl`) on the signed-in user, on a
/// job's client and on each applicant. No link means initials are shown.
void main() {
  group('AuthUser.photoUrl', () {
    Map<String, dynamic> user({Object? photoUrl = _absent}) => {
      'id': 'u1',
      'email': 'ada@uni.edu.ng',
      'role': 'talent',
      'fullName': 'Ada Obi',
      'emailVerified': true,
      if (photoUrl != _absent) 'photoUrl': photoUrl,
    };

    test('is read from the server', () {
      expect(AuthUser.fromJson(user(photoUrl: 'https://files.test/avatars/u1/a.png')).photoUrl, 'https://files.test/avatars/u1/a.png');
    });

    test('is null when the server sends null or nothing (older servers)', () {
      expect(AuthUser.fromJson(user(photoUrl: null)).photoUrl, isNull);
      expect(AuthUser.fromJson(user()).photoUrl, isNull);
    });
  });

  group('Job.clientPhotoUrl', () {
    Map<String, dynamic> job(Map<String, dynamic>? client) => {
      'id': 'j1',
      'title': 'Logo',
      'category': 'Design & creative',
      'description': 'd',
      'budget': '45000.00',
      'createdAt': '2026-10-20T10:00:00Z',
      'client': ?client,
    };

    test('comes from the job\'s client', () {
      final j = Job.fromJson(job({'id': 'c1', 'fullName': 'Chinedu', 'photoUrl': 'https://files.test/avatars/c1/a.jpg'}));
      expect(j.clientPhotoUrl, 'https://files.test/avatars/c1/a.jpg');
    });

    test('is null without a photo, or without a client at all', () {
      expect(Job.fromJson(job({'id': 'c1', 'fullName': 'Chinedu', 'photoUrl': null})).clientPhotoUrl, isNull);
      expect(Job.fromJson(job({'id': 'c1', 'fullName': 'Chinedu'})).clientPhotoUrl, isNull);
      expect(Job.fromJson(job(null)).clientPhotoUrl, isNull);
    });

    test('copyWith keeps it', () {
      final j = Job.fromJson(job({'id': 'c1', 'fullName': 'Chinedu', 'photoUrl': 'https://files.test/a.jpg'}));
      expect(j.copyWith(applicationCount: 3).clientPhotoUrl, 'https://files.test/a.jpg');
    });
  });

  group('JobApplication.talentPhotoUrl', () {
    Map<String, dynamic> app(Map<String, dynamic>? talent) => {
      'id': 'a1',
      'jobId': 'j1',
      'status': 'pending',
      'createdAt': '2026-10-01T10:00:00Z',
      'talent': ?talent,
    };

    test('comes from the applicant', () {
      expect(JobApplication.fromJson(app({'id': 't1', 'fullName': 'Ada', 'photoUrl': 'https://files.test/avatars/t1/a.webp'})).talentPhotoUrl, 'https://files.test/avatars/t1/a.webp');
    });

    test('is null without a photo or without a talent', () {
      expect(JobApplication.fromJson(app({'id': 't1', 'fullName': 'Ada'})).talentPhotoUrl, isNull);
      expect(JobApplication.fromJson(app(null)).talentPhotoUrl, isNull);
    });
  });
}

const _absent = Object();
