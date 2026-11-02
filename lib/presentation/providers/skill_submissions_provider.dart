import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../core/debug_log.dart';
import '../../data/api_client.dart';
import '../../data/models/skill_submission.dart';
import 'auth_provider.dart';

/// Every skill and where the person stands in it (GET /users/me/skills).
final skillHubProvider = FutureProvider<SkillHub>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  final json = await ApiClient.instance.get('/users/me/skills') as Map<String, dynamic>;
  return SkillHub.fromJson(json);
});

final submissionProvider = FutureProvider.family<SubmissionDetail, String>((ref, id) async {
  final json = await ApiClient.instance.get('/users/me/submissions/$id') as Map<String, dynamic>;
  return SubmissionDetail.fromJson(json['submission'] as Map<String, dynamic>);
});

/// Earlier attempts in a skill, newest first.
final skillHistoryProvider = FutureProvider.family<List<HistoryEntry>, String>((ref, skillKey) async {
  final json = await ApiClient.instance.get('/users/me/skills/$skillKey/submissions') as Map<String, dynamic>;
  return [for (final s in json['submissions'] as List) HistoryEntry.fromJson(s as Map<String, dynamic>)];
});

/// A file the person chose, ready to be read as a stream so a big video never sits in memory whole.
class PickedFile {
  final String name;
  final int size;
  final String contentType;
  final Stream<List<int>> Function() open;
  const PickedFile({required this.name, required this.size, required this.contentType, required this.open});
}

const _types = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'pdf': 'application/pdf',
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'zip': 'application/zip',
  'txt': 'text/plain',
  'json': 'application/json',
};

/// The content type for a file name. Unknown extensions (a project file, a PSD) are plain binary, which the
/// server accepts only for working files and drafts and serves as a download.
String contentTypeFor(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return _types[ext] ?? 'application/octet-stream';
}

/// Where chosen files come from. A seam so tests can hand over files without a phone.
abstract class FileGateway {
  /// Photos and videos from the gallery.
  Future<List<PickedFile>> pickMedia();

  /// Any file: a PDF, a document, a project file, a zip.
  Future<List<PickedFile>> pickDocuments();

  /// Records a video with the camera (the walkthrough).
  Future<PickedFile?> recordVideo();

  /// A video already on the phone, such as a screen recording.
  Future<PickedFile?> pickVideo();
}

class DeviceFileGateway implements FileGateway {
  const DeviceFileGateway();

  Future<PickedFile> _fromXFile(XFile x) async {
    final name = x.name.isEmpty ? 'file' : x.name;
    return PickedFile(name: name, size: await x.length(), contentType: contentTypeFor(name), open: () => x.openRead());
  }

  @override
  Future<List<PickedFile>> pickMedia() async {
    final picked = await ImagePicker().pickMultipleMedia();
    return [for (final x in picked) await _fromXFile(x)];
  }

  @override
  Future<List<PickedFile>> pickDocuments() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, withReadStream: false);
    if (result == null) return const [];
    return [
      for (final f in result.files)
        if (f.path != null) PickedFile(name: f.name, size: f.size, contentType: contentTypeFor(f.name), open: () => File(f.path!).openRead()),
    ];
  }

  @override
  Future<PickedFile?> recordVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 3));
    return x == null ? null : _fromXFile(x);
  }

  @override
  Future<PickedFile?> pickVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    return x == null ? null : _fromXFile(x);
  }
}

final fileGatewayProvider = Provider<FileGateway>((ref) => const DeviceFileGateway());

/// Sends bytes to a presigned storage link. Not the API client: the link is not on our server and must not
/// get our sign-in token.
abstract class BlobUploader {
  Future<void> put(String url, Map<String, String> headers, Stream<List<int>> data, int length, {void Function(double fraction)? onProgress});
}

class HttpBlobUploader implements BlobUploader {
  const HttpBlobUploader();

  @override
  Future<void> put(String url, Map<String, String> headers, Stream<List<int>> data, int length, {void Function(double fraction)? onProgress}) async {
    final target = Uri.parse(url);
    kdLog('upload', 'PUT ${target.host}${target.path} $length bytes, headers ${headers.keys.join(',')}');
    final started = DateTime.now();
    final request = http.StreamedRequest('PUT', target)
      ..headers.addAll(headers)
      ..contentLength = length;
    var sent = 0;
    unawaited(
      data.map((chunk) {
        sent += chunk.length;
        onProgress?.call(length == 0 ? 1 : sent / length);
        return chunk;
      }).pipe(request.sink),
    );
    try {
      final response = await request.send().timeout(const Duration(minutes: 20));
      kdLog('upload', 'storage answered ${response.statusCode} after ${DateTime.now().difference(started).inSeconds} s');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('The upload was refused (${response.statusCode}). Try adding the file again.', response.statusCode);
      }
    } on TimeoutException {
      kdLog('upload', 'timed out after ${DateTime.now().difference(started).inSeconds} s');
      throw ApiException('The upload took too long. Check your connection and try again.', 0);
    } on http.ClientException catch (e) {
      kdLog('upload', 'interrupted: ${e.message}');
      throw ApiException('The upload was interrupted. Check your connection and try again.', 0);
    } on SocketException catch (e) {
      kdLog('upload', 'socket error: ${e.message}');
      throw ApiException('The upload was interrupted. Check your connection and try again.', 0);
    }
  }
}

final blobUploaderProvider = Provider<BlobUploader>((ref) => const HttpBlobUploader());

class SubmissionActions {
  final Ref _ref;
  SubmissionActions(this._ref);

  ApiClient get _api => ApiClient.instance;

  void _refresh(String id) {
    _ref.invalidate(submissionProvider(id));
    _ref.invalidate(skillHubProvider);
  }

  /// Starts a draft, or returns the one already open. Throws ApiException with code 'restricted',
  /// 'in_review' or 'already_verified' when the person can't start one.
  Future<SubmissionDetail> startOrContinue(String skillKey) async {
    final json = await _api.post('/users/me/skills/$skillKey/submissions') as Map<String, dynamic>;
    _ref.invalidate(skillHubProvider);
    return SubmissionDetail.fromJson(json['submission'] as Map<String, dynamic>);
  }

  Future<void> discard(String id) async {
    await _api.delete('/users/me/submissions/$id');
    _refresh(id);
  }

  Future<void> updateDeclaration(String id, {bool? ownWork, bool? aiUsed, String? aiNote, bool? acceptTerms}) async {
    await _api.patch('/users/me/submissions/$id', body: {
      'declaredOwnWork': ?ownWork,
      'aiUsed': ?aiUsed,
      'aiNote': ?aiNote,
      'acceptTerms': ?acceptTerms,
    });
    _refresh(id);
  }

  Future<void> addPiece(String id) async {
    await _api.post('/users/me/submissions/$id/pieces', body: {});
    _refresh(id);
  }

  Future<void> savePiece(String id, String pieceId, {required String title, required String brief, required String role, required String madeOn, required String liveLink, String processLink = ''}) async {
    await _api.patch('/users/me/submissions/$id/pieces/$pieceId', body: {'title': title, 'brief': brief, 'role': role, 'madeOn': madeOn, 'liveLink': liveLink, 'processLink': processLink});
    _refresh(id);
  }

  Future<void> deletePiece(String id, String pieceId) async {
    await _api.delete('/users/me/submissions/$id/pieces/$pieceId');
    _refresh(id);
  }

  /// Asks for a link, sends the file to it, then confirms. If the upload fails the half-made file is removed,
  /// so the person never sees a ghost entry.
  Future<void> addFile(String id, {required FileRole role, String? pieceId, required PickedFile file, void Function(double fraction)? onProgress}) async {
    final json = await _api.post('/users/me/submissions/$id/files', body: {
      'role': role.name,
      'pieceId': ?pieceId,
      'name': file.name,
      'contentType': file.contentType,
      'sizeBytes': file.size,
    }) as Map<String, dynamic>;
    final ticket = UploadTicket.fromJson(json);
    kdLog('upload', 'ticket for ${file.name} (${file.size} bytes, ${file.contentType}) as ${role.name}: file=${ticket.file.id}');
    try {
      await _ref.read(blobUploaderProvider).put(ticket.url, ticket.headers, file.open(), file.size, onProgress: onProgress);
      await _api.post('/users/me/submissions/$id/files/${ticket.file.id}/complete');
      kdLog('upload', 'confirmed file=${ticket.file.id}: the server read it back from storage');
    } catch (e) {
      kdLog('upload', 'FAILED file=${ticket.file.id} ${file.name}: $e. Removing the half-made file.');
      try {
        await _api.delete('/users/me/submissions/$id/files/${ticket.file.id}');
      } catch (_) {
        // The draft screen refreshes below; a leftover pending file is invisible there and cleaned with the draft.
      }
      _refresh(id);
      rethrow;
    }
    _refresh(id);
  }

  Future<void> deleteFile(String id, String fileId) async {
    await _api.delete('/users/me/submissions/$id/files/$fileId');
    _refresh(id);
  }

  Future<void> submit(String id) async {
    await _api.post('/users/me/submissions/$id/submit');
    _refresh(id);
  }
}

final submissionActionsProvider = Provider<SubmissionActions>((ref) => SubmissionActions(ref));
