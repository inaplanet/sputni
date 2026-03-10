import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import '../config/stream_settings.dart';
import '../signaling/signaling_client.dart';
import '../signaling/signaling_message.dart';
import '../ui/azure_theme.dart';
import '../utils/app_logger.dart';
import '../webrtc/rtc_manager.dart';
import '../widgets/app_shell_ui.dart';
import '../widgets/pairing_panel.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final _roomController = TextEditingController(text: 'demo-room');

  late final AppConfig _config;
  SignalingClient? _signaling;
  RtcManager? _rtc;
  StreamSettings _settings = StreamSettings.monitorDefaults;
  PairingMethod _pairingMethod = PairingMethod.roomId;
  String _status = 'Offline';
  String _connectionReport = 'P2P first · idle';

  StreamSettings _responsiveSettings(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return _settings.copyWith(
      videoProfile: VideoProfile.adaptive(
        screenWidth: size.width,
        screenHeight: size.height,
        role: StreamViewportRole.monitor,
        preset: _settings.videoQualityPreset,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _config = AppConfig.fromEnvironment();
  }

  Future<void> _connect() async {
    if (_signaling != null || _rtc != null) return;

    final effectiveSettings = _responsiveSettings(context);
    final signaling = SignalingClient(serverUrl: _config.signalingUrl);
    final rtc = RtcManager(
      role: PeerRole.monitor,
      config: _config,
      settings: effectiveSettings,
    );

    signaling.onConnected = () {
      setState(() => _status = 'Listening');
      signaling.send(
        SignalingMessage(
          type: SignalingMessageType.join,
          payload: {'roomId': _roomController.text, 'role': 'monitor'},
        ),
      );
    };

    signaling.onMessage = (message) async {
      if (message.type == SignalingMessageType.control) {
        final action = message.payload['action'];
        if (mounted) {
          setState(() => _status = 'Control $action');
        }
      }
      await rtc.handleSignalingMessage(message);
    };

    signaling.onError = (error, [stack]) {
      setState(() => _status = 'Error: $error');
      AppLogger.error('Monitor signaling error', error, stack);
    };

    signaling.onDisconnected = () {
      if (mounted) {
        setState(() => _status = 'Disconnected');
      }
    };

    rtc.onSignal = signaling.send;
    rtc.onConnectionState = (state) {
      if (mounted) {
        setState(() => _status = 'Peer ${state.name}');
      }
    };
    rtc.onDiagnosticsChanged = (diagnostics) {
      if (mounted) {
        setState(() => _connectionReport = diagnostics);
      }
    };

    await rtc.initialize();
    await signaling.connect();

    if (!mounted) return;
    setState(() {
      _settings = effectiveSettings;
      _signaling = signaling;
      _rtc = rtc;
      _status = 'Awaiting camera';
      _connectionReport = rtc.connectionSummary;
    });
  }

  Future<void> _disconnect() async {
    await _signaling?.disconnect();
    await _rtc?.dispose();

    if (!mounted) return;
    setState(() {
      _signaling = null;
      _rtc = null;
      _status = 'Disconnected';
      _connectionReport = 'P2P first · idle';
    });
  }

  @override
  void dispose() {
    _roomController.dispose();
    _signaling?.disconnect();
    _rtc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _rtc != null;
    final canConnect = !isConnected;
    final canDisconnect = isConnected;
    final effectiveSettings = _responsiveSettings(context);
    final pairingPayload = buildPairingPayload(
      roomId: _roomController.text.trim().isEmpty
          ? 'demo-room'
          : _roomController.text.trim(),
      signalingUrl: _config.signalingUrl,
      role: 'monitor',
    );

    return AppShell(
      title: 'Monitor',
      subtitle: 'Viewer dashboard with controls and connection diagnostics.',
      hero: SurfacePanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                StatusPill(
                  label: _status,
                  color: isConnected ? AzureTheme.success : AzureTheme.warning,
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: _resolvedMonitorAspectRatio(effectiveSettings),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFF081A33)),
                  child: _rtc == null
                      ? const Center(
                          child: Text(
                            'Remote feed will appear here',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            RTCVideoView(
                              _rtc!.remoteRenderer,
                              objectFit: effectiveSettings.rtcVideoFit,
                            ),
                            if (effectiveSettings.lowLightBoost)
                              Container(
                                color: Colors.lightBlueAccent
                                    .withValues(alpha: 0.08),
                              ),
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  effectiveSettings.videoProfileLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      panels: [
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PairingMethodTabs(
                activeMethod: _pairingMethod,
                onChanged: (method) => setState(() => _pairingMethod = method),
              ),
              const SizedBox(height: 16),
              if (_pairingMethod == PairingMethod.roomId)
                TextField(
                  controller: _roomController,
                  decoration: const InputDecoration(labelText: 'Room ID'),
                  onChanged: (_) => setState(() {}),
                )
              else
                PairingQrCodeCard(
                  payload: pairingPayload,
                  title: 'QR pairing',
                  subtitle:
                      'Share this monitor pairing code without opening the camera.',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ViewerChip(
                      label: _settings.viewerPriority.name.toUpperCase()),
                  _ViewerChip(
                      label: _settings.videoFit == VideoFitMode.cover
                          ? 'FILL'
                          : 'FIT'),
                  _ViewerChip(label: effectiveSettings.videoProfileLabel),
                  _ViewerChip(label: '${_config.stunUrls.length} STUN servers'),
                ],
              ),
            ],
          ),
        ),
        if (_settings.showConnectionReport)
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection report',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(_connectionReport),
                const SizedBox(height: 8),
                Text(
                  'Relay remains a last resort. This viewer only gathers TURN candidates after the session asks for fallback or direct ICE fails.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AzureTheme.ink.withValues(alpha: 0.65),
                      ),
                ),
              ],
            ),
          ),
      ],
      actions: [
        ElevatedButton(
          onPressed: canConnect ? _connect : null,
          child: const Text('Connect'),
        ),
        OutlinedButton(
          onPressed: canDisconnect ? _disconnect : null,
          child: const Text('Disconnect'),
        ),
      ],
    );
  }

  double _resolvedMonitorAspectRatio(StreamSettings effectiveSettings) {
    final renderer = _rtc?.remoteRenderer;
    final videoWidth = renderer?.videoWidth ?? 0;
    final videoHeight = renderer?.videoHeight ?? 0;

    if (videoWidth > 0 && videoHeight > 0) {
      return videoWidth / videoHeight;
    }

    return effectiveSettings.videoProfile.previewAspectRatio;
  }
}

class _ViewerChip extends StatelessWidget {
  const _ViewerChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E7FF)),
      ),
      child: Text(label),
    );
  }
}
