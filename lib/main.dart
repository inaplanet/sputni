import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'camera_view/camera_screen.dart';
import 'monitor_view/monitor_screen.dart';
import 'routes/app_routes.dart';
import 'ui/azure_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    initVideoPlayerMediaKitIfNeeded();
  }
  runApp(const TeleckApp());
}

class TeleckApp extends StatelessWidget {
  const TeleckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teleck',
      theme: AzureTheme.theme(),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const _HomeScreen(),
        AppRoutes.camera: (_) => const CameraScreen(),
        AppRoutes.monitor: (_) => const MonitorScreen(),
      },
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE6F4FF), Color(0xFFF8FBFF), Color(0xFFD7EBFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: -70,
                left: -10,
                child: _HomeGlow(size: 220, color: Color(0x661279FF)),
              ),
              const Positioned(
                top: 140,
                right: -40,
                child: _HomeGlow(size: 190, color: Color(0x556BD7FF)),
              ),
              const Positioned(
                bottom: -90,
                left: 80,
                child: _HomeGlow(size: 250, color: Color(0x40B4DDFF)),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teleck',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pair devices and control your environment.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 720;
                          final cards = [
                            _RoleCard(
                              title: 'Camera',
                              subtitle:
                                  'Send live video with P2P-first ICE and relay fallback only when needed.',
                              actionLabel: 'Open camera',
                              assetPath: 'assets/media/cameramode.mp4',
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.camera),
                            ),
                            _RoleCard(
                              title: 'Monitor',
                              subtitle:
                                  'Watch the stream with viewer-focused controls and connection reporting.',
                              actionLabel: 'Open monitor',
                              assetPath: 'assets/media/monitormode.mp4',
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.monitor,
                              ),
                            ),
                          ];

                          if (isCompact) {
                            return Column(
                              children: [
                                Expanded(child: cards[0]),
                                const SizedBox(height: 16),
                                Expanded(child: cards[1]),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 16),
                              Expanded(child: cards[1]),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.assetPath,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final String assetPath;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (!_supportsAssetVideoPlayback) {
      return;
    }

    try {
      final controller = VideoPlayerController.asset(widget.assetPath);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() => _controller = controller);
    } on UnimplementedError {
      debugPrint(
        'Video playback is not implemented on ${defaultTargetPlatform.name}. '
        'Using gradient fallback for ${widget.assetPath}.',
      );
    } catch (error) {
      debugPrint(
        'Failed to initialize video background for ${widget.assetPath}: $error',
      );
    }
  }

  bool get _supportsAssetVideoPlayback {
    if (kIsWeb) return true;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return true;
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isVideoReady = controller != null && controller.value.isInitialized;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AzureTheme.glassStroke,
                  width: 1.1,
                ),
              ),
            ),
            if (isVideoReady)
              Positioned.fill(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: ExcludeSemantics(
                        child: VideoPlayer(controller),
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B5DCC), Color(0xFF071A36)],
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: widget.onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.1,
                      ),
                      disabledForegroundColor: Colors.white54,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      side: BorderSide.none,
                    ),
                    child: Text(widget.actionLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeGlow extends StatelessWidget {
  const _HomeGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
