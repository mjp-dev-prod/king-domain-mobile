import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/debug_log.dart';
import '../../data/api_client.dart';
import '../../data/models/sent_work.dart';

/// Everything one submission contains, with private links that expire (about an hour). Refreshing gets fresh links.
final sentWorkProvider = FutureProvider.autoDispose.family<SentWork, String>((ref, submissionId) async {
  final json = await ApiClient.instance.get('/users/me/submissions/$submissionId/work') as Map<String, dynamic>;
  return SentWork.fromJson(json);
});

/// What a link looks like when it is opened. The server fetches it (and refuses anything that isn't on the public web).
final linkPreviewProvider = FutureProvider.autoDispose.family<LinkPreview, String>((ref, url) async {
  final json = await ApiClient.instance.get('/users/link-preview?url=${Uri.encodeQueryComponent(url)}') as Map<String, dynamic>;
  return LinkPreview.fromJson(json);
});

/// Reads how long a video is. A seam so a screen test can answer without a phone's video decoder.
abstract class MediaProbe {
  Future<Duration?> videoLength(String url);
}

class PlayerMediaProbe implements MediaProbe {
  const PlayerMediaProbe();

  @override
  Future<Duration?> videoLength(String url) async {
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize().timeout(const Duration(seconds: 20));
      return c.value.duration;
    } catch (e) {
      kdLog('media', 'could not read the length of a video: $e');
      return null;
    } finally {
      await c.dispose();
    }
  }
}

final mediaProbeProvider = Provider<MediaProbe>((ref) => const PlayerMediaProbe());

/// A video's real length, or null if it can't be read. Read once per link: a refresh gets new links, so it reads again.
final videoLengthProvider = FutureProvider.autoDispose.family<Duration?, ({String name, String url})>((ref, f) => ref.read(mediaProbeProvider).videoLength(f.url));
