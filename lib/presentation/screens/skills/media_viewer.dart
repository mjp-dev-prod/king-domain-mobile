import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/debug_log.dart';
import '../../../data/models/sent_work.dart';
import '../../widgets/kit/evidence_viewer.dart' show formatBytes;

/// Opens a sent file the way it deserves: a picture in a gallery you can swipe and pinch, a video in a proper player, anything
/// else (a PDF, a project file) in the phone's own app for it. [files] is the group it belongs to, so swiping works.
Future<void> openSentFile(BuildContext context, List<SentFile> files, SentFile file) async {
  final url = file.url;
  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This file can\'t be opened right now. Pull down to refresh the screen and try again.')));
    return;
  }
  switch (file.kind) {
    case SentKind.image:
      final images = [for (final f in files) if (f.kind == SentKind.image && f.url != null) f];
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImageGalleryScreen(images: images, initial: images.indexWhere((f) => f.id == file.id).clamp(0, images.length - 1))));
    case SentKind.video:
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url, title: file.name)));
    default:
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app on this phone can open that kind of file.')));
  }
}

/// Pictures, full screen: swipe between them, pinch and double-tap to zoom.
class ImageGalleryScreen extends StatefulWidget {
  final List<SentFile> images;
  final int initial;
  const ImageGalleryScreen({super.key, required this.images, this.initial = 0});

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
          Text('${_index + 1} of ${widget.images.length} · ${formatBytes(f.sizeBytes)}', style: AppTextStyles.hint.copyWith(color: Colors.white70)),
        ]),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.images.length,
        // While zoomed in, a drag pans the picture instead of turning the page.
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => _ZoomableImage(url: widget.images[i].url!, onZoomed: (z) => setState(() => _zoomed = z)),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String url;
  final ValueChanged<bool> onZoomed;
  const _ZoomableImage({required this.url, required this.onZoomed});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _controller = TransformationController();
  TapDownDetails? _tap;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => widget.onZoomed(_controller.value.getMaxScaleOnAxis() > 1.02));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final at = _tap?.localPosition ?? Offset.zero;
    if (_controller.value.getMaxScaleOnAxis() > 1.02) {
      _controller.value = Matrix4.identity();
    } else {
      _controller.value = Matrix4.identity()
        ..translateByDouble(-at.dx * 1.5, -at.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 2.5, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tap = d,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
            errorBuilder: (_, _, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40),
                const SizedBox(height: 12),
                Text('This picture couldn\'t be loaded. Go back and pull down to refresh, then open it again.', textAlign: TextAlign.center, style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

String clock(Duration d) {
  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// A video player that is pleasant to use: tap to show or hide the controls, play and pause, drag to seek, jump back or
/// forward 10 seconds, change the speed, go full screen, replay at the end, and a plain message with Retry when it can't play.
class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  const VideoPlayerScreen({super.key, required this.url, required this.title});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _c;
  String? _error;
  bool _ready = false;
  bool _controls = true;
  bool _landscape = false;
  bool _scrubbing = false;
  double _speed = 1;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))..addListener(_tick);
    try {
      await _c.initialize().timeout(const Duration(seconds: 25));
      if (!mounted) return;
      await _c.setPlaybackSpeed(_speed);
      setState(() => _ready = true);
      await _c.play();
      _scheduleHide();
    } catch (e) {
      kdLog('video', 'could not play ${widget.title}: $e');
      if (mounted) setState(() => _error = 'This video couldn\'t be played. It may still be loading, or your connection dropped.');
    }
  }

  void _tick() {
    if (!mounted) return;
    final v = _c.value;
    if (v.hasError && _error == null) setState(() => _error = 'Playback stopped: ${v.errorDescription ?? 'the video couldn\'t be read'}.');
    setState(() {});
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && _c.value.isPlaying && !_scrubbing) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  Future<void> _playPause() async {
    final v = _c.value;
    if (v.position >= v.duration && v.duration > Duration.zero) await _c.seekTo(Duration.zero);
    v.isPlaying ? await _c.pause() : await _c.play();
    setState(() => _controls = true);
    _scheduleHide();
  }

  Future<void> _jump(int seconds) async {
    final v = _c.value;
    final target = v.position + Duration(seconds: seconds);
    await _c.seekTo(target < Duration.zero ? Duration.zero : (target > v.duration ? v.duration : target));
    _scheduleHide();
  }

  Future<void> _fullscreen() async {
    _landscape = !_landscape;
    await SystemChrome.setPreferredOrientations(_landscape ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : const [DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(_landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hide?.cancel();
    _c.removeListener(_tick);
    _c.dispose();
    // Put the phone back the way it was.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    final ended = _ready && v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _ErrorView(message: _error!, onRetry: () async {
                await _c.dispose();
                await _start();
              }, onOpenElsewhere: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication))
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: Stack(children: [
                  Center(child: _ready ? AspectRatio(aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio, child: VideoPlayer(_c)) : const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)),
                  if (_ready && v.isBuffering) const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
                  AnimatedOpacity(
                    opacity: _controls || ended || !_ready ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !(_controls || ended),
                      child: Stack(children: [
                        Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87], stops: [0, .25, .65, 1]))),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Row(children: [
                            IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                            Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white))),
                            if (_ready)
                              PopupMenuButton<double>(
                                tooltip: 'Playback speed',
                                initialValue: _speed,
                                icon: const Icon(Icons.speed_rounded, color: Colors.white),
                                onSelected: (s) {
                                  setState(() => _speed = s);
                                  _c.setPlaybackSpeed(s);
                                },
                                itemBuilder: (_) => [for (final s in const [0.5, 1.0, 1.25, 1.5, 2.0]) PopupMenuItem(value: s, child: Text(s == 1 ? 'Normal' : '${s}x'))],
                              ),
                          ]),
                        ),
                        if (_ready)
                          Center(
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(iconSize: 36, tooltip: 'Back 10 seconds', onPressed: () => _jump(-10), icon: const Icon(Icons.replay_10_rounded, color: Colors.white)),
                              const SizedBox(width: 12),
                              Container(
                                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                child: IconButton(
                                  iconSize: 56,
                                  tooltip: ended ? 'Play again' : (v.isPlaying ? 'Pause' : 'Play'),
                                  onPressed: _playPause,
                                  icon: Icon(ended ? Icons.replay_rounded : (v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded), color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(iconSize: 36, tooltip: 'Forward 10 seconds', onPressed: () => _jump(10), icon: const Icon(Icons.forward_10_rounded, color: Colors.white)),
                            ]),
                          ),
                        if (_ready)
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 4,
                            child: Row(children: [
                              Text(clock(v.position), style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()])),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7), activeTrackColor: AppColors.primary, inactiveTrackColor: Colors.white24, thumbColor: AppColors.primaryText, overlayShape: SliderComponentShape.noOverlay),
                                  child: Slider(
                                    value: v.position.inMilliseconds.clamp(0, v.duration.inMilliseconds == 0 ? 1 : v.duration.inMilliseconds).toDouble(),
                                    max: (v.duration.inMilliseconds == 0 ? 1 : v.duration.inMilliseconds).toDouble(),
                                    onChangeStart: (_) => _scrubbing = true,
                                    onChanged: (x) => _c.seekTo(Duration(milliseconds: x.round())),
                                    onChangeEnd: (_) {
                                      _scrubbing = false;
                                      _scheduleHide();
                                    },
                                  ),
                                ),
                              ),
                              Text(clock(v.duration), style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontFeatures: const [FontFeature.tabularFigures()])),
                              IconButton(tooltip: _landscape ? 'Exit full screen' : 'Full screen', onPressed: _fullscreen, icon: Icon(_landscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white)),
                            ]),
                          ),
                      ]),
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenElsewhere;
  const _ErrorView({required this.message, required this.onRetry, required this.onOpenElsewhere});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Align(alignment: Alignment.centerLeft, child: IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white))),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 44),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: 8),
            TextButton(onPressed: onOpenElsewhere, child: const Text('Open in another app')),
          ]),
        ),
      ),
    ]);
  }
}
