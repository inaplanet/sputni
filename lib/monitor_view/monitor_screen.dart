import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/app_config.dart';
import '../config/stream_settings.dart';
import '../signaling/signaling_client.dart';
import '../signaling/signaling_message.dart';
import '../ui/azure_theme.dart';
import '../utils/app_logger.dart';
import '../webrtc/rtc_manager.dart';
import '../widgets/alfred_camera_ui.dart';
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
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  PairingMethod _pairingMethod = PairingMethod.roomId;
  bool _isHandlingScan = false;
  String _status = 'Offline';
  String _connectionReport = 'P2P first · idle';

  StreamSettings _responsiveSettings(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return _settings.copyWith(
      videoProfile: VideoProfile.adaptive(
        screenWidth: size.width,
        screenHeight: size.height,
        role: StreamViewportRole.monitor,
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

  Future<void> _openSettings() async {
    final updatedSettings = await showAlfredSettingsSheet(
      context: context,
      title: 'Viewer settings',
      initialSettings: _settings,
      turnAvailable: _config.hasTurnServer,
    );

    if (updatedSettings == null || !mounted) return;

    setState(() => _settings = updatedSettings);
    await _rtc?.updateSettings(updatedSettings);
  }

  Future<void> _handleQrScan(String rawValue) async {
    if (_isHandlingScan) return;

    final roomId = parseRoomIdFromPairingPayload(rawValue);
    if (roomId == null) {
      if (mounted) {
        setState(() => _status = 'Invalid QR code');
      }
      return;
    }

    _isHandlingScan = true;
    try {
      _roomController.text = roomId;
      if (mounted) {
        setState(() {
          _status = 'QR paired';
          _pairingMethod = PairingMethod.qrCode;
        });
      }

      if (_rtc == null && _signaling == null) {
        await _connect();
      }
    } finally {
      await Future<void>.delayed(const Duration(seconds: 2));
      _isHandlingScan = false;
    }
  }

  Future<void> _setPairingMethod(PairingMethod method) async {
    if (_pairingMethod == method) return;

    setState(() => _pairingMethod = method);
    if (method == PairingMethod.qrCode) {
      await _scannerController.start();
    } else {
      await _scannerController.stop();
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _scannerController.dispose();
    _signaling?.disconnect();
    _rtc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _rtc != null;
    final effectiveSettings = _responsiveSettings(context);

    return AlfredShell(
      title: 'Monitor',
      subtitle:
          'Viewer dashboard with Alfred-style controls and Azure status cards.',
      hero: SurfacePanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                StatusPill(
                  label: _status,
                  color: isConnected ? AzureTheme.success : AzureTheme.warning,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: _resolvedMonitorAspectRatio(effectiveSettings),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
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
                onChanged: (method) {
                  _setPairingMethod(method);
                },
              ),
              const SizedBox(height: 16),
              if (_pairingMethod == PairingMethod.roomId)
                TextField(
                  controller: _roomController,
                  decoration: const InputDecoration(labelText: 'Room ID'),
                )
              else
                PairingQrScannerCard(
                  controller: _scannerController,
                  onDetect: _handleQrScan,
                  title: 'QR pairing',
                  subtitle:
                      'Point the monitor camera at the camera screen QR code.',
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
          onPressed: _connect,
          child: const Text('Connect'),
        ),
        OutlinedButton(
          onPressed: _disconnect,
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
