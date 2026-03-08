class TokenManager {
  const TokenManager();

  /// In production, replace with secure storage / OAuth refresh handling.
  Future<String?> getAccessToken() async {
    return const String.fromEnvironment('SIGNALING_TOKEN', defaultValue: '');
  }

  Future<Map<String, String>> authorizationHeaders() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) {
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }
}
