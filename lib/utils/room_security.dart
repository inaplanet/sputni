import 'dart:convert';

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
