import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:king_domain/core/theme/app_theme.dart';
import 'package:king_domain/data/api_client.dart';
import 'package:king_domain/presentation/providers/auth_provider.dart';
import 'package:king_domain/presentation/providers/photo_picker.dart';
import 'package:king_domain/presentation/screens/profile/profile_photo_button.dart';
import 'package:king_domain/presentation/widgets/kit/kd_layout.dart';

const _newUrl = 'https://files.test/avatars/new.png';

class _Auth extends AuthNotifier {
  _Auth({this.photoUrl, this.uploadError});
  final String? photoUrl;
  final ApiException? uploadError;
  final calls = <String>[];

  @override
  AuthState build() => AuthState(
    loading: false,
    user: AuthUser(id: 'u1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true, photoUrl: photoUrl),
  );

  @override
  Future<void> setPhoto(List<int> bytes, String fileName) async {
    calls.add('set:$fileName:${bytes.length}');
    if (uploadError != null) throw uploadError!;
    state = state.copyWith(user: AuthUser(id: 'u1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true, photoUrl: _newUrl));
  }

  @override
  Future<void> removePhoto() async {
    calls.add('remove');
    state = state.copyWith(user: const AuthUser(id: 'u1', email: 'ada@uni.edu.ng', role: 'talent', fullName: 'Ada Obi', emailVerified: true));
  }
}

class _Picker implements PhotoPicker {
  _Picker({this.result, this.error});
  final PickedPhoto? result;
  final Object? error;
  final sources = <ImageSource>[];

  @override
  Future<PickedPhoto?> pick(ImageSource source) async {
    sources.add(source);
    if (error != null) throw error!;
    return result;
  }
}

final _photo = PickedPhoto(bytes: Uint8List.fromList([1, 2, 3]), name: 'me.jpg');

Future<void> _show(WidgetTester tester, _Auth auth, _Picker picker) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authProvider.overrideWith(() => auth), photoPickerProvider.overrideWithValue(picker)],
    child: MaterialApp(
      theme: AppTheme.theme,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const Scaffold(body: Center(child: ProfilePhotoButton(size: 84))),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(ProfilePhotoButton));
  await tester.pumpAndSettle();
}

Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the person with a camera mark that says it can be changed', (tester) async {
    final handle = tester.ensureSemantics();
    await _show(tester, _Auth(), _Picker());
    expect(find.byType(UserAvatar), findsOneWidget);
    expect(find.text('AO'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('Change profile photo'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tapping opens the choices; there is nothing to remove yet', (tester) async {
    await _show(tester, _Auth(), _Picker());
    await _openSheet(tester);
    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
  });

  testWidgets('with a photo already, Remove photo is offered', (tester) async {
    await _show(tester, _Auth(photoUrl: 'https://files.test/avatars/old.png'), _Picker());
    await _openSheet(tester);
    expect(find.text('Remove photo'), findsOneWidget);
  });

  testWidgets('gallery: picks from the gallery, uploads the file, closes, says so, and shows the new photo', (tester) async {
    final auth = _Auth();
    final picker = _Picker(result: _photo);
    await _show(tester, auth, picker);
    await _openSheet(tester);
    await tester.tap(find.text('Choose from gallery'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(picker.sources, [ImageSource.gallery]);
    expect(auth.calls, ['set:me.jpg:3']);
    expect(find.text('Choose from gallery'), findsNothing, reason: 'the sheet closed');
    expect(find.text('Photo updated.'), findsOneWidget);
    expect((tester.widget<Image>(find.byType(Image)).image as NetworkImage).url, _newUrl);
    await _drainToasts(tester);
  });

  testWidgets('camera: uses the camera', (tester) async {
    final auth = _Auth();
    final picker = _Picker(result: _photo);
    await _show(tester, auth, picker);
    await _openSheet(tester);
    await tester.tap(find.text('Take a photo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(picker.sources, [ImageSource.camera]);
    expect(auth.calls, ['set:me.jpg:3']);
    await _drainToasts(tester);
  });

  testWidgets('cancelling the picker uploads nothing and closes quietly', (tester) async {
    final auth = _Auth();
    await _show(tester, auth, _Picker());
    await _openSheet(tester);
    await tester.tap(find.text('Choose from gallery'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(auth.calls, isEmpty);
    expect(find.text('Choose from gallery'), findsNothing);
    expect(find.text('Photo updated.'), findsNothing);
  });

  testWidgets('a refused upload shows the server\'s reason and keeps the choices open for another try', (tester) async {
    final auth = _Auth(uploadError: ApiException('That file type isn\'t supported. Choose a JPG, PNG or WebP picture.', 415, code: 'unsupported_file'));
    await _show(tester, auth, _Picker(result: _photo));
    await _openSheet(tester);
    await tester.tap(find.text('Choose from gallery'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('That file type isn\'t supported. Choose a JPG, PNG or WebP picture.'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Photo updated.'), findsNothing);
    await _drainToasts(tester);
  });

  testWidgets('if the phone refuses access to photos or the camera, the person is told what to check', (tester) async {
    await _show(tester, _Auth(), _Picker(error: Exception('permission denied')));
    await _openSheet(tester);
    await tester.tap(find.text('Take a photo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check the app\'s permissions'), findsOneWidget);
    await _drainToasts(tester);
  });

  testWidgets('Remove photo removes it, closes, says so, and the initials come back', (tester) async {
    final auth = _Auth(photoUrl: 'https://files.test/avatars/old.png');
    await _show(tester, auth, _Picker());
    await _openSheet(tester);
    await tester.tap(find.text('Remove photo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(auth.calls, ['remove']);
    expect(find.text('Photo removed.'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('AO'), findsOneWidget);
    await _drainToasts(tester);
  });
}
