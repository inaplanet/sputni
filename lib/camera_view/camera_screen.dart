import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

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

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _roomController = TextEditingController(text: 'first-channel');

  late final AppConfig _config;
  SignalingClient? _signaling;
  RtcManager? _rtc;
  StreamSettings _settings = StreamSettings.cameraDefaults;
  PairingMethod _pairingMethod = PairingMethod.roomId;
  String _status = 'Standby';
  String _connectionReport = 'P2P first · waiting to start';
  String? _recordingPath;

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
      role: StreamViewportRole.camera,
    );
  }

  @override
  void initState() {
    super.initState();
    _config = AppConfig.fromEnvironment();
  }

  Future<void> _startStreaming() async {
    if (_signaling != null || _rtc != null) return;

    final effectiveSettings = _responsiveSettings(context);
    final signaling = SignalingClient(serverUrl: _config.signalingUrl);
    final rtc = RtcManager(
      role: PeerRole.camera,
      config: _config,
      settings: effectiveSettings,
    );

    signaling.onConnected = () {
      setState(() => _status = 'Session broker ready');
      signaling.send(
        SignalingMessage(
          type: SignalingMessageType.join,
          payload: {'roomId': _transmissionRoomId, 'role': 'camera'},
        ),
      );
      signaling.send(
        const SignalingMessage(
          type: SignalingMessageType.control,
          payload: {'action': 'start'},
        ),
      );
    };

    signaling.onMessage = (message) async {
      if (message.type == SignalingMessageType.control) {
        AppLogger.info('Camera received control: ${message.payload}');
      }
      await rtc.handleSignalingMessage(message);
    };

    signaling.onError = (error, [stack]) {
      setState(() => _status = 'Connection issue');
      AppLogger.error('Camera signaling error', error, stack);
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
    if (!mounted) return;
    setState(() {
      _settings = effectiveSettings;
      _rtc = rtc;
      _status = 'Camera preview ready';
      _connectionReport = rtc.connectionSummary;
    });

    await signaling.connect();

    final offer = await rtc.createOffer();
    signaling.send(offer);

    if (!mounted) return;
    setState(() {
      _signaling = signaling;
      _status = 'Waiting for viewer';
      _connectionReport = rtc.connectionSummary;
    });
  }

  Future<void> _stopStreaming() async {
    _signaling?.send(
      const SignalingMessage(
        type: SignalingMessageType.control,
        payload: {'action': 'stop'},
      ),
    );

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

  Future<void> _openSettings() async {
    final updatedSettings = await showSettingsSheet(
      context: context,
      title: 'Camera settings',
      initialSettings: _settings,
      turnAvailable: _config.hasTurnServer,
    );

    if (updatedSettings == null || !mounted) return;

    setState(() => _settings = updatedSettings);
    await _rtc?.updateSettings(_responsiveSettings(context));
  }

  Future<void> _toggleRecording() async {
    final rtc = _rtc;
    if (rtc == null) return;

    if (rtc.isRecording) {
      await rtc.stopRecording();
      if (!mounted) return;
      setState(() => _status = 'Recording saved');
      return;
    }

    final baseDirectory = await getApplicationSupportDirectory();
    final recordingsDirectory = Directory(
      '${baseDirectory.path}/AetherLinkRecordings',
    );

    if (!await recordingsDirectory.exists()) {
      await recordingsDirectory.create(recursive: true);
    }

    final filePath =
        '${recordingsDirectory.path}/camera_${DateTime.now().millisecondsSinceEpoch}.mp4';

    await rtc.startRecording(filePath);

    if (!mounted) return;
    setState(() {
      _recordingPath = filePath;
      _status = 'Recording locally';
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

  MetricTone _statusTone() {
    if (_rtc == null) return MetricTone.neutral;
    if (_status == 'Secure link active') {
      return MetricTone.good;
    }
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
        label: effectiveSettings.preferDirectP2P
            ? 'Direct route preferred'
            : 'Auto route',
        icon: Icons.hub_rounded,
        tone: effectiveSettings.preferDirectP2P
            ? MetricTone.good
            : MetricTone.warning,
      ),
      MetricBadge(
        label: '${_config.stunUrls.length} STUN servers',
        icon: Icons.public_rounded,
        tone:
            _config.stunUrls.length > 1 ? MetricTone.good : MetricTone.warning,
      ),
      MetricBadge(
        label: _config.hasTurnServer && effectiveSettings.enableTurnFallback
            ? 'TURN on standby'
            : 'TURN off',
        icon: Icons.compare_arrows_rounded,
        tone: _config.hasTurnServer && effectiveSettings.enableTurnFallback
            ? MetricTone.good
            : MetricTone.danger,
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
    final isStreaming = _rtc != null;
    final canStart = !isStreaming;
    final canStop = isStreaming;
    final effectiveSettings = _responsiveSettings(context);
    final pairingPayload = buildPairingPayload(
      roomId: _transmissionRoomId,
      signalingUrl: _config.signalingUrl,
      role: 'camera',
    );

    return AppShell(
      title: 'Camera',
      subtitle:
          'Live camera controls with P2P connection and adaptive capture.',
      hero: SurfacePanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  label: _status,
                  color: _statusColor(),
                ),
                const Spacer(),
                if (_rtc?.isRecording ?? false)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: StatusPill(
                      label: 'REC',
                      color: Color(0xFFD7263D),
                    ),
                  ),
                IconButton(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: effectiveSettings.videoProfile.previewAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFF0A1830)),
                  child: _rtc == null
                      ? const Center(
                          child: Text(
                            'Preview unavailable until streaming starts',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            RTCVideoView(
                              _rtc!.localRenderer,
                              mirror: false,
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
                'Route status: $_connectionReport. Secure device pairing is active and relay remains a last-resort path.',
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
                  subtitle: 'Scan this code on the monitor to pair instantly.',
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  MetricBadge(
                    label: effectiveSettings.powerSaveMode
                        ? 'Power save on'
                        : 'Power save off',
                    icon: effectiveSettings.powerSaveMode
                        ? Icons.battery_saver_rounded
                        : Icons.battery_full_rounded,
                  ),
                  MetricBadge(
                    label: 'Bitrate ${effectiveSettings.bitrateLabel}',
                    icon: Icons.speed_rounded,
                  ),
                  MetricBadge(
                    label: 'Quality ${effectiveSettings.qualityPresetLabel}',
                    icon: Icons.high_quality_rounded,
                  ),
                  MetricBadge(
                    label: effectiveSettings.enableMicrophone
                        ? 'Voice enabled'
                        : 'Voice disabled',
                    icon: effectiveSettings.enableMicrophone
                        ? Icons.mic_rounded
                        : Icons.mic_off_rounded,
                  ),
                  MetricBadge(
                    label: '${_config.stunUrls.length} STUN servers',
                    icon: Icons.public_rounded,
                  ),
                  MetricBadge(
                    label: _config.hasTurnServer && _settings.enableTurnFallback
                        ? 'TURN enabled'
                        : 'TURN disabled',
                    icon: Icons.compare_arrows_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_recordingPath != null)
          SurfacePanel(
            child: Text(
              'Recording saved to $_recordingPath',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AzureTheme.ink.withValues(alpha: 0.72),
                  ),
            ),
          ),
      ],
      actions: [
        ElevatedButton(
          onPressed: canStart ? _startStreaming : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill_rounded),
              SizedBox(width: 8),
              Text('Start live'),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: canStop ? _stopStreaming : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stop_circle_rounded),
              SizedBox(width: 8),
              Text('Stop'),
            ],
          ),
        ),
        if (isStreaming)
          OutlinedButton(
            onPressed: _toggleRecording,
            child: Text(
              (_rtc?.isRecording ?? false) ? 'Stop rec' : 'Start rec',
            ),
          ),
      ],
    );
  }
}
