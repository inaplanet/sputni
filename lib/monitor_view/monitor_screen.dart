import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import '../config/stream_settings.dart';
import '../signaling/signaling_client.dart';
import '../signaling/signaling_message.dart';
import '../ui/azure_theme.dart';
import '../utils/app_logger.dart';
import '../utils/room_security.dart';
import '../webrtc/rtc_manager.dart';
import '../widgets/app_shell_ui.dart';
import '../widgets/pairing_panel.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final _roomController = TextEditingController(text: 'first-channel');

  late final AppConfig _config;
  SignalingClient? _signaling;
  RtcManager? _rtc;
  StreamSettings _settings = StreamSettings.monitorDefaults;
  PairingMethod _pairingMethod = PairingMethod.roomId;
  String _status = 'Standby';
  String _connectionReport = 'P2P first · idle';

  String get _resolvedRoomId {
    final value = _roomController.text.trim();
    return value.isEmpty ? 'first-channel' : value;
  }

  String get _transmissionRoomId => secureRoomToken(_resolvedRoomId);

  StreamSettings _responsiveSettings(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return _settings.resolvedForViewport(
      screenWidth: size.width,
      screenHeight: size.height,
      role: StreamViewportRole.monitor,
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
      setState(() => _status = 'Session broker ready');
      signaling.send(
        SignalingMessage(
          type: SignalingMessageType.join,
          payload: {'roomId': _transmissionRoomId, 'role': 'monitor'},
        ),
      );
    };

    signaling.onMessage = (message) async {
      if (message.type == SignalingMessageType.control) {
        final action = message.payload['action'];
        if (mounted) {
          setState(() => _status = _controlStatusLabel(action?.toString()));
        }
      }
      await rtc.handleSignalingMessage(message);
    };

    signaling.onError = (error, [stack]) {
      setState(() => _status = 'Connection issue');
      AppLogger.error('Monitor signaling error', error, stack);
    };

    signaling.onDisconnected = () {
      if (mounted) {
        setState(() => _status = 'Session closed');
      }
    };

    rtc.onSignal = signaling.send;
    rtc.onConnectionState = (state) {
      if (mounted) {
        setState(() => _status = _peerStateLabel(state));
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
      _status = 'Waiting for camera';
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
      _status = 'Standby';
      _connectionReport = 'P2P first · idle';
    });
  }

  String _peerStateLabel(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return 'Preparing secure link';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return 'Establishing secure link';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return 'Secure link active';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return 'Link interrupted';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return 'Connection failed';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return 'Session closed';
    }
  }

  String _controlStatusLabel(String? action) {
    switch (action) {
      case 'start':
        return 'Camera went live';
      case 'stop':
        return 'Camera stopped streaming';
      default:
        return 'Control update received';
    }
  }

  MetricTone _statusTone() {
    if (_rtc == null) return MetricTone.neutral;
    if (_status == 'Secure link active') return MetricTone.good;
    if (_status == 'Link interrupted' || _status == 'Connection failed') {
      return MetricTone.danger;
    }
    return MetricTone.warning;
  }

  Color _statusColor() {
    switch (_statusTone()) {
      case MetricTone.good:
        return AzureTheme.success;
      case MetricTone.warning:
        return AzureTheme.warning;
      case MetricTone.danger:
        return const Color(0xFFB42318);
      case MetricTone.neutral:
        return AzureTheme.azureDark;
    }
  }

  List<MetricBadge> _connectionHighlights(StreamSettings effectiveSettings) {
    return [
      MetricBadge(
        label: effectiveSettings.viewerPriority.name.toUpperCase(),
        icon: Icons.tune_rounded,
        tone: MetricTone.neutral,
      ),
      MetricBadge(
        label: effectiveSettings.videoFit == VideoFitMode.cover
            ? 'Fill view'
            : 'Fit view',
        icon: effectiveSettings.videoFit == VideoFitMode.cover
            ? Icons.crop_free_rounded
            : Icons.fit_screen_rounded,
        tone: MetricTone.neutral,
      ),
      MetricBadge(
        label: '${_config.stunUrls.length} STUN servers',
        icon: Icons.public_rounded,
        tone:
            _config.stunUrls.length > 1 ? MetricTone.good : MetricTone.warning,
      ),
    ];
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
      roomId: _transmissionRoomId,
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
                  color: _statusColor(),
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
        if (_settings.showConnectionReport)
          ConnectionReportPanel(
            title: 'Connection report',
            summary:
                'Route status: $_connectionReport. Monitor sessions stay optimized for direct delivery first and keep relay as fallback only.',
            highlights: _connectionHighlights(effectiveSettings),
            statusTone: _statusTone(),
          ),
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
                  MetricBadge(
                    label: _settings.viewerPriority.name.toUpperCase(),
                    icon: Icons.tune_rounded,
                  ),
                  MetricBadge(
                    label: _settings.videoFit == VideoFitMode.cover
                        ? 'Fill view'
                        : 'Fit view',
                    icon: _settings.videoFit == VideoFitMode.cover
                        ? Icons.crop_free_rounded
                        : Icons.fit_screen_rounded,
                  ),
                  MetricBadge(
                    label: effectiveSettings.videoProfileLabel,
                    icon: Icons.monitor_rounded,
                  ),
                  MetricBadge(
                    label: '${_config.stunUrls.length} STUN servers',
                    icon: Icons.public_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      actions: [
        ElevatedButton(
          onPressed: canConnect ? _connect : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_tethering_rounded),
              SizedBox(width: 8),
              Text('Connect'),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: canDisconnect ? _disconnect : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_off_rounded),
              SizedBox(width: 8),
              Text('Disconnect'),
            ],
          ),
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
