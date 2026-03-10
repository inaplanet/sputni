class AppConfig {
  const AppConfig({
    required this.signalingUrl,
    required this.enableTurn,
    required this.stunUrls,
    this.turnFallbackDelaySeconds = 8,
    this.turnUrl,
    this.turnUsername,
    this.turnPassword,
  });

  final String signalingUrl;
  final bool enableTurn;
  final List<String> stunUrls;
  final int turnFallbackDelaySeconds;
  final String? turnUrl;
  final String? turnUsername;
  final String? turnPassword;

  factory AppConfig.fromEnvironment() {
    const defaultStunServers = <String>[
      'stun:stun.l.google.com:19302',
      'stun:stun1.l.google.com:19302',
      'stun:stun2.l.google.com:19302',
      'stun:stun.cloudflare.com:3478',
    ];

    const stunServerList = String.fromEnvironment(
      'STUN_URLS',
      defaultValue: '',
    );
    const legacyStunUrl = String.fromEnvironment(
      'STUN_URL',
      defaultValue: 'stun:stun.l.google.com:19302',
    );

    final parsedStunServers = <String>{
      ...stunServerList
          .split(',')
          .map((server) => server.trim())
          .where((server) => server.isNotEmpty),
      if (legacyStunUrl.isNotEmpty) legacyStunUrl,
    }.toList();

    return AppConfig(
      signalingUrl: const String.fromEnvironment('SIGNALING_URL',
          defaultValue: 'wss://aethersignal.onrender.com/ws'),
      enableTurn:
          const bool.fromEnvironment('ENABLE_TURN', defaultValue: false),
      stunUrls:
          parsedStunServers.isEmpty ? defaultStunServers : parsedStunServers,
      turnFallbackDelaySeconds: const int.fromEnvironment(
        'TURN_FALLBACK_DELAY_SECONDS',
        defaultValue: 8,
      ),
      turnUrl: const String.fromEnvironment('TURN_URL', defaultValue: ''),
      turnUsername: const String.fromEnvironment(
        'TURN_USERNAME',
        defaultValue: '',
      ),
      turnPassword: const String.fromEnvironment(
        'TURN_PASSWORD',
        defaultValue: '',
      ),
    );
  }

  bool get hasTurnServer => enableTurn && (turnUrl?.isNotEmpty ?? false);

  List<Map<String, dynamic>> iceServers({bool includeTurn = false}) {
    final servers = <Map<String, dynamic>>[
      {'urls': stunUrls},
    ];

    if (includeTurn && hasTurnServer) {
      servers.add({
        'urls': turnUrl,
        'username': turnUsername,
        'credential': turnPassword,
      });
    }

    return servers;
  }

  Map<String, dynamic> peerConnectionConfiguration({bool includeTurn = false}) {
    return {
      'iceServers': iceServers(includeTurn: includeTurn),
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'balanced',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 4,
      'sdpSemantics': 'unified-plan',
    };
  }
}
