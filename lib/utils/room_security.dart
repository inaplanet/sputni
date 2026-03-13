import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String secureRoomToken(String roomId) {
  if (isSecureRoomToken(roomId)) {
    return roomId.trim();
  }
  final normalized = roomId.trim().toLowerCase();
  final digest = sha256.convert(utf8.encode(normalized));
  final token = base64UrlEncode(digest.bytes).replaceAll('=', '');
  return 'enc_$token';
}

bool isSecureRoomToken(String value) => value.trim().startsWith('enc_');

String generateSecureRoomToken() {
  final random = Random.secure();
  final entropy = StringBuffer('qr-${DateTime.now().microsecondsSinceEpoch}');
  for (var index = 0; index < 4; index += 1) {
    entropy.write('-${random.nextInt(1 << 32)}');
  }
  return secureRoomToken(entropy.toString());
}
