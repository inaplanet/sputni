import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import '../signaling/signaling_message.dart';
import '../utils/app_logger.dart';

enum PeerRole { camera, monitor }

class RtcManager {
  RtcManager({
    required this.role,
    required this.config,
  });

  final PeerRole role;
  final AppConfig config;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  void Function(SignalingMessage message)? onSignal;
  void Function(RTCPeerConnectionState state)? onConnectionState;

  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    _peerConnection = await createPeerConnection(
      {
        'iceServers': config.iceServers,
        'sdpSemantics': 'unified-plan',
      },
      {
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      },
    );

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      onConnectionState?.call(state);
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      onSignal?.call(
        SignalingMessage(
          type: SignalingMessageType.iceCandidate,
          payload: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        ),
      );
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
    };

    if (role == PeerRole.camera) {
      await _startLocalCapture();
    }
  }

  // Future<void> _startLocalCapture() async {
  //   final mediaConstraints = {
  //     'audio': false,
  //     'video': {
  //       'facingMode': 'environment',
  //       if (defaultTargetPlatform == TargetPlatform.iOS)
  //         'mandatory': {
  //           'minWidth': '640',
  //           'minHeight': '480',
  //           'minFrameRate': '24',
  //         }
  //       else
  //         'width': 640,
  //     },
  //   };

  //   _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  //   localRenderer.srcObject = _localStream;

  //   for (final track in _localStream!.getTracks()) {
  //     await _peerConnection!.addTrack(track, _localStream!);
  //   }
  // }

  Future<void> _startLocalCapture() async {
    final devices = await navigator.mediaDevices.enumerateDevices();

    debugPrint('====== RTC DEVICE LIST ======');
    for (final d in devices) {
      debugPrint('device: kind=${d.kind} label=${d.label} id=${d.deviceId}');
    }
    debugPrint('====== END DEVICE LIST ======');

    final mediaConstraints = {
      'audio': false,
      'video': true,
    };

    debugPrint('RTC: requesting getUserMedia with constraints: $mediaConstraints');

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    debugPrint('RTC: local stream created: ${_localStream?.id}');
    debugPrint('RTC: video tracks = ${_localStream?.getVideoTracks().length}');
    debugPrint('RTC: audio tracks = ${_localStream?.getAudioTracks().length}');

    localRenderer.srcObject = _localStream;

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }
  }

  Future<SignalingMessage> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    return SignalingMessage(
      type: SignalingMessageType.offer,
      payload: {
        'type': offer.type,
        'sdp': offer.sdp,
      },
    );
  }

  Future<SignalingMessage> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    return SignalingMessage(
      type: SignalingMessageType.answer,
      payload: {
        'type': answer.type,
        'sdp': answer.sdp,
      },
    );
  }

  Future<void> handleSignalingMessage(SignalingMessage message) async {
    switch (message.type) {
      case SignalingMessageType.offer:
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            message.payload['sdp'] as String,
            message.payload['type'] as String,
          ),
        );
        final answer = await createAnswer();
        onSignal?.call(answer);
        break;
      case SignalingMessageType.answer:
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            message.payload['sdp'] as String,
            message.payload['type'] as String,
          ),
        );
        break;
      case SignalingMessageType.iceCandidate:
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            message.payload['candidate'] as String?,
            message.payload['sdpMid'] as String?,
            message.payload['sdpMLineIndex'] as int?,
          ),
        );
        break;
      case SignalingMessageType.control:
      case SignalingMessageType.join:
        AppLogger.info('Control/join handled by screen coordinator: ${message.payload}');
        break;
    }
  }

  Future<void> dispose() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
