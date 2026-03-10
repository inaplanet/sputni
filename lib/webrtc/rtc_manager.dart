import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import '../config/stream_settings.dart';
import '../signaling/signaling_message.dart';
import '../utils/app_logger.dart';

enum PeerRole { camera, monitor }

class RtcManager {
  RtcManager({
    required this.role,
    required this.config,
    required StreamSettings settings,
  }) : _settings = settings;

  final PeerRole role;
  final AppConfig config;

  StreamSettings _settings;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Timer? _turnFallbackTimer;
  bool _isTurnFallbackActive = false;
  bool _isIceRestartInFlight = false;
  bool _seenRelayCandidate = false;
  bool _seenSrflxCandidate = false;
  bool _seenHostCandidate = false;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  void Function(SignalingMessage message)? onSignal;
  void Function(RTCPeerConnectionState state)? onConnectionState;
  void Function(String diagnostics)? onDiagnosticsChanged;

  bool get isTurnFallbackActive => _isTurnFallbackActive;
  String get connectionSummary => _buildConnectionSummary();

  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    _peerConnection = await createPeerConnection(
      config.peerConnectionConfiguration(includeTurn: false),
      {
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      },
    );

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      _handlePeerConnectionState(state);
      onConnectionState?.call(state);
    };

    _peerConnection!.onIceConnectionState = _handleIceConnectionState;

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _trackCandidateType(candidate.candidate!);
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

    _scheduleTurnFallback();
    _emitDiagnostics();
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
      'video': {
        'facingMode': 'environment',
        'width': _settings.videoProfile.width,
        'height': _settings.videoProfile.height,
        'frameRate': _settings.videoProfile.frameRate,
      },
    };

    debugPrint(
        'RTC: requesting getUserMedia with constraints: $mediaConstraints');

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    debugPrint('RTC: local stream created: ${_localStream?.id}');
    debugPrint('RTC: video tracks = ${_localStream?.getVideoTracks().length}');
    debugPrint('RTC: audio tracks = ${_localStream?.getAudioTracks().length}');

    localRenderer.srcObject = _localStream;

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    await _applyVideoBitrateSettings();
  }

  Future<SignalingMessage> createOffer({bool iceRestart = false}) async {
    final offer = await _peerConnection!.createOffer(
      iceRestart ? {'iceRestart': true} : {},
    );
    await _peerConnection!.setLocalDescription(offer);

    return SignalingMessage(
      type: SignalingMessageType.offer,
      payload: {
        'type': offer.type,
        'sdp': offer.sdp,
        'turnFallback': _isTurnFallbackActive,
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
        'turnFallback': _isTurnFallbackActive,
      },
    );
  }

  Future<void> updateSettings(StreamSettings settings) async {
    _settings = settings;
    _scheduleTurnFallback();
    await _applyVideoBitrateSettings();
    _emitDiagnostics();
  }

  Future<void> handleSignalingMessage(SignalingMessage message) async {
    switch (message.type) {
      case SignalingMessageType.offer:
        if (message.payload['turnFallback'] == true) {
          await _activateTurnFallback(
              reason: 'remote-request', renegotiate: false);
        }
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
        if (message.payload['turnFallback'] == true) {
          await _activateTurnFallback(
              reason: 'relay-answer', renegotiate: false);
        }
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
        AppLogger.info(
            'Control/join handled by screen coordinator: ${message.payload}');
        break;
    }
  }

  Future<void> dispose() async {
    _turnFallbackTimer?.cancel();
    await _localStream?.dispose();
    await _peerConnection?.close();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }

  void _handlePeerConnectionState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _turnFallbackTimer?.cancel();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        unawaited(_activateTurnFallback(reason: 'connection-failed'));
        break;
      default:
        break;
    }
    _emitDiagnostics();
  }

  void _handleIceConnectionState(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _turnFallbackTimer?.cancel();
        break;
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        unawaited(_activateTurnFallback(reason: state.name));
        break;
      default:
        break;
    }
    _emitDiagnostics();
  }

  void _scheduleTurnFallback() {
    _turnFallbackTimer?.cancel();

    if (!_settings.preferDirectP2P ||
        !_settings.enableTurnFallback ||
        _isTurnFallbackActive ||
        !config.hasTurnServer) {
      return;
    }

    _turnFallbackTimer = Timer(
      Duration(seconds: config.turnFallbackDelaySeconds),
      () => unawaited(_activateTurnFallback(reason: 'stun-timeout')),
    );
  }

  Future<void> _activateTurnFallback({
    required String reason,
    bool renegotiate = true,
  }) async {
    if (_isTurnFallbackActive ||
        _isIceRestartInFlight ||
        !_settings.enableTurnFallback ||
        !config.hasTurnServer) {
      return;
    }

    _isIceRestartInFlight = true;
    _isTurnFallbackActive = true;
    _turnFallbackTimer?.cancel();

    try {
      await _peerConnection?.setConfiguration(
        config.peerConnectionConfiguration(includeTurn: true),
      );
      await _peerConnection?.restartIce();
      if (renegotiate) {
        final offer = await createOffer(iceRestart: true);
        onSignal?.call(offer);
      }
      AppLogger.info('TURN fallback activated: $reason');
    } catch (error, stackTrace) {
      AppLogger.error('Failed to activate TURN fallback', error, stackTrace);
    } finally {
      _isIceRestartInFlight = false;
      _emitDiagnostics();
    }
  }

  Future<void> _applyVideoBitrateSettings() async {
    if (role != PeerRole.camera) return;

    final peerConnection = _peerConnection;
    if (peerConnection == null) return;

    try {
      final senders = await peerConnection.getSenders();
      RTCRtpSender? videoSender;

      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          videoSender = sender;
          break;
        }
      }

      if (videoSender == null) return;

      final parameters = videoSender.parameters;
      final encodings =
          parameters.encodings ?? <RTCRtpEncoding>[RTCRtpEncoding()];
      if (encodings.isEmpty) {
        encodings.add(RTCRtpEncoding());
      }

      final maxBitrate = _settings.maxVideoBitrateKbps * 1000;
      for (final encoding in encodings) {
        encoding.maxBitrate = maxBitrate;
        encoding.priority = _encodingPriorityFor(_settings.viewerPriority);
        encoding.maxFramerate =
            _settings.viewerPriority == ViewerPriorityMode.smooth ? 30 : 24;
        encoding.scaleResolutionDownBy =
            _settings.viewerPriority == ViewerPriorityMode.clarity ? 1.0 : 1.15;
      }

      parameters.encodings = encodings;
      parameters.degradationPreference =
          _degradationPreferenceFor(_settings.viewerPriority);
      await videoSender.setParameters(parameters);
    } catch (error, stackTrace) {
      AppLogger.error(
          'Failed to apply video bitrate settings', error, stackTrace);
    }
  }

  RTCPriorityType _encodingPriorityFor(ViewerPriorityMode mode) {
    switch (mode) {
      case ViewerPriorityMode.balanced:
        return RTCPriorityType.medium;
      case ViewerPriorityMode.smooth:
        return RTCPriorityType.low;
      case ViewerPriorityMode.clarity:
        return RTCPriorityType.high;
    }
  }

  RTCDegradationPreference _degradationPreferenceFor(ViewerPriorityMode mode) {
    switch (mode) {
      case ViewerPriorityMode.balanced:
        return RTCDegradationPreference.BALANCED;
      case ViewerPriorityMode.smooth:
        return RTCDegradationPreference.MAINTAIN_FRAMERATE;
      case ViewerPriorityMode.clarity:
        return RTCDegradationPreference.MAINTAIN_RESOLUTION;
    }
  }

  void _trackCandidateType(String candidate) {
    if (candidate.contains(' typ relay ')) {
      _seenRelayCandidate = true;
    }
    if (candidate.contains(' typ srflx ')) {
      _seenSrflxCandidate = true;
    }
    if (candidate.contains(' typ host ')) {
      _seenHostCandidate = true;
    }
    _emitDiagnostics();
  }

  String _buildConnectionSummary() {
    final transport =
        _isTurnFallbackActive ? 'TURN fallback armed' : 'P2P first';
    final candidates = [
      if (_seenHostCandidate) 'host',
      if (_seenSrflxCandidate) 'srflx',
      if (_seenRelayCandidate) 'relay',
    ];
    if (candidates.isEmpty) {
      return '$transport · gathering candidates';
    }
    return '$transport · seen ${candidates.join('/')}';
  }

  void _emitDiagnostics() {
    onDiagnosticsChanged?.call(_buildConnectionSummary());
  }
}
