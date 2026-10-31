import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../data/models/identity.dart';
import 'auth_provider.dart';

/// Where the signed-in person stands on identity (GET /users/me/identity).
final identityProvider = FutureProvider<IdentitySummary>((ref) async {
  // Re-read when the account changes (sign-in, sign-out).
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/users/me/identity') as Map<String, dynamic>;
  return IdentitySummary.fromJson(json['identity'] as Map<String, dynamic>);
});

/// The region and education line the person has saved, read from /users/me.
class AboutYou {
  final Region? region;
  final EducationLine? education;
  final String? clientKind;
  const AboutYou({this.region, this.education, this.clientKind});

  factory AboutYou.fromUserJson(Map<String, dynamic> user) => AboutYou(
    region: user['region'] == null ? null : Region.fromJson(user['region'] as Map<String, dynamic>),
    education: user['education'] == null ? null : EducationLine.fromJson(user['education'] as Map<String, dynamic>),
    clientKind: user['clientKind'] as String?,
  );

  bool isDoneFor(bool isClient) => region != null && (isClient ? clientKind != null : education != null);
}

final aboutYouProvider = FutureProvider<AboutYou>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/users/me') as Map<String, dynamic>;
  return AboutYou.fromUserJson(json['user'] as Map<String, dynamic>);
});

class IdentityActions {
  final Ref _ref;
  IdentityActions(this._ref);

  Future<void> saveAboutYou({
    required String country,
    String? state,
    String? city,
    EducationKind? educationKind,
    String? school,
    String? detail,
    String? clientKind,
  }) async {
    await ApiClient.instance.patch('/users/me/region-education', body: {
      'country': country,
      if (state != null && state.isNotEmpty) 'state': state,
      if (city != null && city.isNotEmpty) 'city': city,
      'educationKind': ?educationKind?.name,
      if (school != null && school.isNotEmpty) 'educationSchool': school,
      if (detail != null && detail.isNotEmpty) 'educationDetail': detail,
      'clientKind': ?clientKind,
    });
    _ref.invalidate(aboutYouProvider);
  }

  Future<void> submitIdentity({
    required IdentityDocument document,
    required String number,
    required String fullName,
    String? dateOfBirth,
    required List<int> documentBytes,
    required String documentName,
    List<int>? videoBytes,
    String? videoName,
  }) async {
    await ApiClient.instance.postMultipartParts(
      '/users/me/identity',
      fields: {
        'document': document.name,
        'documentNumber': number,
        'fullName': fullName,
        'dateOfBirth': ?dateOfBirth,
      },
      parts: [
        UploadPart(field: 'document', bytes: documentBytes, name: documentName),
        if (videoBytes != null) UploadPart(field: 'video', bytes: videoBytes, name: videoName ?? 'selfie.mp4'),
      ],
    );
    _ref.invalidate(identityProvider);
  }

  Future<void> inviteGuardian({required String name, required String email, required String relationship}) async {
    await ApiClient.instance.post('/users/me/guardian', body: {'guardianName': name, 'guardianEmail': email, 'relationship': relationship});
    _ref.invalidate(identityProvider);
  }
}

final identityActionsProvider = Provider<IdentityActions>((ref) => IdentityActions(ref));
