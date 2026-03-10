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
import '../webrtc/rtc_manager.dart';
import '../widgets/app_shell_ui.dart';
import '../widgets/pairing_panel.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _roomController = TextEditingController(text: 'demo-room');

  late final AppConfig _config;
  SignalingClient? _signaling;
  RtcManager? _rtc;
  StreamSettings _settings = StreamSettings.cameraDefaults;
  PairingMethod _pairingMethod = PairingMethod.roomId;
  String _status = 'Offline';
  String _connectionReport = 'P2P first · waiting to start';
  String? _recordingPath;

  StreamSettings _responsiveSettings(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return _settings.copyWith(
      videoProfile: VideoProfile.adaptive(
        screenWidth: size.width,
        screenHeight: size.height,
        role: StreamViewportRole.camera,
        preset: _settings.videoQualityPreset,
      ),
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
      setState(() => _status = 'Signaling connected');
      signaling.send(
        SignalingMessage(
          type: SignalingMessageType.join,
          payload: {'roomId': _roomController.text, 'role': 'camera'},
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
      setState(() => _status = 'Error: $error');
      AppLogger.error('Camera signaling error', error, stack);
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
    if (!mounted) return;
    setState(() {
      _settings = effectiveSettings;
      _rtc = rtc;
      _status = 'Camera ready';
      _connectionReport = rtc.connectionSummary;
    });

    await signaling.connect();

    final offer = await rtc.createOffer();
    signaling.send(offer);

    if (!mounted) return;
    setState(() {
      _signaling = signaling;
      _status = 'Live';
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
      _status = 'Stopped';
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
    await _rtc?.updateSettings(updatedSettings);
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

    final baseDirectory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
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
      _status = 'Recording';
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
    final isStreaming = _rtc != null;
    final canStart = !isStreaming;
    final canStop = isStreaming;
    final effectiveSettings = _responsiveSettings(context);
    final pairingPayload = buildPairingPayload(
      roomId: _roomController.text.trim().isEmpty
          ? 'demo-room'
          : _roomController.text.trim(),
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
                  color:
                      isStreaming ? AzureTheme.success : AzureTheme.azureDark,
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
                  _InfoChip(label: 'Bitrate ${_settings.bitrateLabel}'),
                  _InfoChip(label: effectiveSettings.videoProfileLabel),
                  _InfoChip(
                    label: effectiveSettings.enableMicrophone
                        ? 'Voice enabled'
                        : 'Voice disabled',
                  ),
                  _InfoChip(label: '${_config.stunUrls.length} STUN servers'),
                  _InfoChip(
                    label: _config.hasTurnServer
                        ? 'TURN fallback ready'
                        : 'TURN disabled',
                  ),
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
                  'TURN is not forced. The app starts with STUN-only gathering and only promotes relay when direct connectivity times out or fails.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AzureTheme.ink.withValues(alpha: 0.65),
                      ),
                ),
                if (_recordingPath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Saved to $_recordingPath',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AzureTheme.ink.withValues(alpha: 0.65),
                        ),
                  ),
                ],
              ],
            ),
          ),
      ],
      actions: [
        ElevatedButton(
          onPressed: canStart ? _startStreaming : null,
          child: const Text('Start live'),
        ),
        OutlinedButton(
          onPressed: canStop ? _stopStreaming : null,
          child: const Text('Stop'),
        ),
        if (isStreaming)
          OutlinedButton(
            onPressed: _toggleRecording,
            child:
                Text((_rtc?.isRecording ?? false) ? 'Stop rec' : 'Start rec'),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

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
