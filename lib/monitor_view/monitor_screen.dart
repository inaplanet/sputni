import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import '../signaling/signaling_client.dart';
import '../signaling/signaling_message.dart';
import '../utils/app_logger.dart';
import '../webrtc/rtc_manager.dart';

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
  String _status = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _config = AppConfig.fromEnvironment();
  }

  Future<void> _connect() async {
    if (_signaling != null || _rtc != null) return;

    final signaling = SignalingClient(serverUrl: _config.signalingUrl);
    final rtc = RtcManager(role: PeerRole.monitor, config: _config);

    signaling.onConnected = () {
      setState(() => _status = 'Connected to signaling server');
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
        if (mounted) setState(() => _status = 'Control: $action');
      }
      await rtc.handleSignalingMessage(message);
    };

    signaling.onError = (error, [stack]) {
      setState(() => _status = 'Error: $error');
      AppLogger.error('Monitor signaling error', error, stack);
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

    setState(() {
      _signaling = signaling;
      _rtc = rtc;
      _status = 'Awaiting offer';
    });
  }

  Future<void> _disconnect() async {
    await _signaling?.disconnect();
    await _rtc?.dispose();

    setState(() {
      _signaling = null;
      _rtc = null;
      _status = 'Disconnected';
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
      appBar: AppBar(title: const Text('Monitor')),
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
                  ? const Center(child: Text('Remote feed will appear here'))
                  : RTCVideoView(
                      _rtc!.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _connect,
                    child: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _disconnect,
                    child: const Text('Disconnect'),
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
