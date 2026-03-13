import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../config/stream_settings.dart';

Future<Directory> resolveRecordingDirectory(StreamSettings settings) async {
  switch (settings.recordingDirectoryMode) {
    case RecordingDirectoryMode.documents:
      final baseDirectory = await getApplicationDocumentsDirectory();
      return Directory(
        '${baseDirectory.path}${Platform.pathSeparator}TeleckRecordings',
      );
    case RecordingDirectoryMode.appSupport:
      final baseDirectory = await getApplicationSupportDirectory();
      return Directory(
        '${baseDirectory.path}${Platform.pathSeparator}TeleckRecordings',
      );
    case RecordingDirectoryMode.temporary:
      final baseDirectory = await getTemporaryDirectory();
      return Directory(
        '${baseDirectory.path}${Platform.pathSeparator}TeleckRecordings',
      );
    case RecordingDirectoryMode.custom:
      final customPath = settings.customRecordingDirectoryPath?.trim();
      if (customPath != null && customPath.isNotEmpty) {
        return Directory(customPath);
      }

      final fallbackDirectory = await getApplicationDocumentsDirectory();
      return Directory(
        '${fallbackDirectory.path}${Platform.pathSeparator}TeleckRecordings',
      );
  }
}
