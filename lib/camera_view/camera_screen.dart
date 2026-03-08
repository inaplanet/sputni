import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import '../signaling/signaling_client.dart';
import '../signaling/signaling_message.dart';
import '../utils/app_logger.dart';
import '../webrtc/rtc_manager.dart';

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
  String _status = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _config = AppConfig.fromEnvironment();
  }

  Future<void> _startStreaming() async {
    if (_signaling != null || _rtc != null) return;

    final signaling = SignalingClient(serverUrl: _config.signalingUrl);
    final rtc = RtcManager(role: PeerRole.camera, config: _config);

    signaling.onConnected = () {
      setState(() => _status = 'Connected to signaling server');
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
      if (mounted) setState(() => _status = 'Disconnected');
    };

    rtc.onSignal = signaling.send;
    rtc.onConnectionState = (state) {
      if (mounted) setState(() => _status = 'Peer state: ${state.name}');
    };

    await rtc.initialize();
    await signaling.connect();

    // Camera creates offer once local capture is up.
    final offer = await rtc.createOffer();
    signaling.send(offer);

    setState(() {
      _signaling = signaling;
      _rtc = rtc;
      _status = 'Streaming started';
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

    setState(() {
      _signaling = null;
      _rtc = null;
      _status = 'Stopped';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(labelText: 'Room ID'),
            ),
            const SizedBox(height: 12),
            Text(_status),
            const SizedBox(height: 12),
            Expanded(
              child: _rtc == null
                  ? const Center(child: Text('Preview unavailable until started'))
                  : RTCVideoView(
                      _rtc!.localRenderer,
                      mirror: false,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startStreaming,
                    child: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _stopStreaming,
                    child: const Text('Stop'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
