class AppConfig {
  const AppConfig({
    required this.signalingUrl,
    required this.enableTurn,
    required this.stunUrls,
    this.turnFallbackDelaySeconds = 8,
    this.turnUrls = const <String>[],
    this.turnUsername,
    this.turnCredential,
  });

  final String signalingUrl;
  final bool enableTurn;
  final List<String> stunUrls;
  final int turnFallbackDelaySeconds;
  final List<String> turnUrls;
  final String? turnUsername;
  final String? turnCredential;

  factory AppConfig.fromEnvironment() {
    const defaultStunServers = <String>[
      'stun:stun.l.google.com:19302',
      'stun:stun1.l.google.com:19302',
      'stun:stun2.l.google.com:19302',
      'stun:stun.cloudflare.com:3478',
    ];
    const defaultTurnServers = <String>[
      'turn:turn.teleck.live:3478?transport=udp',
      'turn:turn.teleck.live:3478?transport=tcp',
      'turns:turn.teleck.live:5349?transport=tcp',
    ];

    const stunServerList = String.fromEnvironment(
      'STUN_URLS',
      defaultValue: '',
    );
    const legacyStunUrl = String.fromEnvironment(
      'STUN_URL',
      defaultValue: 'stun:stun.l.google.com:19302',
    );
    const turnServerList = String.fromEnvironment(
      'TURN_URLS',
      defaultValue: '',
    );
    const legacyTurnUrl = String.fromEnvironment('TURN_URL', defaultValue: '');
    const turnCredential = String.fromEnvironment(
      'TURN_CREDENTIAL',
      defaultValue: '',
    );
    const legacyTurnPassword = String.fromEnvironment(
      'TURN_PASSWORD',
      defaultValue: '',
    );

    final parsedStunServers = <String>{
      ...stunServerList
          .split(',')
          .map((server) => server.trim())
          .where((server) => server.isNotEmpty),
      if (legacyStunUrl.isNotEmpty) legacyStunUrl,
    }.toList();
    final parsedTurnServers = <String>{
      ...turnServerList
          .split(',')
          .map((server) => server.trim())
          .where((server) => server.isNotEmpty),
      if (legacyTurnUrl.isNotEmpty) legacyTurnUrl,
    }.toList();

    return AppConfig(
      signalingUrl: const String.fromEnvironment('SIGNALING_URL',
          defaultValue: 'wss://aethersignal.onrender.com/ws'),
      enableTurn:
          const bool.fromEnvironment('ENABLE_TURN', defaultValue: true),
      stunUrls:
          parsedStunServers.isEmpty ? defaultStunServers : parsedStunServers,
      turnFallbackDelaySeconds: const int.fromEnvironment(
        'TURN_FALLBACK_DELAY_SECONDS',
        defaultValue: 8,
      ),
      turnUrls:
          parsedTurnServers.isEmpty ? defaultTurnServers : parsedTurnServers,
      turnUsername: const String.fromEnvironment(
        'TURN_USERNAME',
        defaultValue: '',
      ),
      turnCredential:
          turnCredential.isNotEmpty ? turnCredential : legacyTurnPassword,
    );
  }

  bool get hasTurnServer =>
      enableTurn &&
      turnUrls.isNotEmpty &&
      (turnUsername?.isNotEmpty ?? false) &&
      (turnCredential?.isNotEmpty ?? false);

  List<Map<String, dynamic>> iceServers({
    bool includeTurn = false,
    bool useMultipleStunServers = true,
  }) {
    final selectedStunUrls =
        useMultipleStunServers ? stunUrls : stunUrls.take(1).toList();
    final servers = <Map<String, dynamic>>[
      {'urls': selectedStunUrls},
    ];

    if (includeTurn && hasTurnServer) {
      servers.add({
        'urls': turnUrls,
        'username': turnUsername,
        'credential': turnCredential,
      });
    }

    return servers;
  }

  Map<String, dynamic> peerConnectionConfiguration({
    bool includeTurn = false,
    bool useMultipleStunServers = true,
  }) {
    return {
      'iceServers': iceServers(
        includeTurn: includeTurn,
        useMultipleStunServers: useMultipleStunServers,
      ),
      'iceTransportPolicy': 'all',
      'bundlePolicy': 'balanced',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 4,
      'sdpSemantics': 'unified-plan',
    };
  }
}
