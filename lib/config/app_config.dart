class AppConfig {
  const AppConfig({
    required this.signalingUrl,
    required this.enableTurn,
    required this.stunUrl,
    this.turnUrl,
    this.turnUsername,
    this.turnPassword,
  });

  final String signalingUrl;
  final bool enableTurn;
  final String stunUrl;
  final String? turnUrl;
  final String? turnUsername;
  final String? turnPassword;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      signalingUrl: String.fromEnvironment('SIGNALING_URL', defaultValue: 'ws://192.168.0.108:8080/ws'),
      enableTurn: bool.fromEnvironment('ENABLE_TURN', defaultValue: false),
      stunUrl: String.fromEnvironment('STUN_URL', defaultValue: 'stun:stun.l.google.com:19302'),
      turnUrl: String.fromEnvironment('TURN_URL', defaultValue: ''),
      turnUsername: String.fromEnvironment('TURN_USERNAME', defaultValue: ''),
      turnPassword: String.fromEnvironment('TURN_PASSWORD', defaultValue: ''),
    );
  }

  List<Map<String, dynamic>> get iceServers {
    final servers = <Map<String, dynamic>>[
      {'urls': stunUrl},
    ];

    if (enableTurn && (turnUrl?.isNotEmpty ?? false)) {
      servers.add({
        'urls': turnUrl,
        'username': turnUsername,
        'credential': turnPassword,
      });
    }

    return servers;
  }
}
