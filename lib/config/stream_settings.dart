import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum ViewerPriorityMode { balanced, smooth, clarity }

enum VideoDisplayMode { landscape, portrait }

enum StreamViewportRole { camera, monitor }

enum VideoQualityPreset { auto, dataSaver, balanced, high }

enum ExposureMode { high, balanced, low }

enum CameraLightMode { day, night }

enum DeviceViewportClass { phone, tablet, desktop }

enum RecordingDirectoryMode { documents, appSupport, temporary, custom }

extension DeviceViewportClassResolver on DeviceViewportClass {
  static DeviceViewportClass fromViewport({
    required double screenWidth,
    required double screenHeight,
  }) {
    final shortestSide =
        screenWidth < screenHeight ? screenWidth : screenHeight;
    final longestSide = screenWidth > screenHeight ? screenWidth : screenHeight;
    final platform = defaultTargetPlatform;
    final isDesktopPlatform = kIsWeb ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;

    if (isDesktopPlatform) {
      return DeviceViewportClass.desktop;
    }
    if (shortestSide >= 700 || longestSide >= 1100) {
      return DeviceViewportClass.tablet;
    }
    return DeviceViewportClass.phone;
  }
}

class VideoProfile {
  const VideoProfile({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.previewAspectRatio,
    required this.label,
  });

  final int width;
  final int height;
  final int frameRate;
  final double previewAspectRatio;
  final String label;

  VideoProfile copyWith({
    int? width,
    int? height,
    int? frameRate,
    double? previewAspectRatio,
    String? label,
  }) {
    return VideoProfile(
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
      previewAspectRatio: previewAspectRatio ?? this.previewAspectRatio,
      label: label ?? this.label,
    );
  }

  static const cameraPowerSave = VideoProfile(
    width: 640,
    height: 360,
    frameRate: 15,
    previewAspectRatio: 9 / 16,
    label: 'Power save',
  );

  static VideoProfile powerSaveFor(DeviceViewportClass deviceClass) {
    final isPhone = deviceClass == DeviceViewportClass.phone;
    return VideoProfile(
      width: isPhone ? 640 : 960,
      height: isPhone ? 1136 : 540,
      frameRate: 15,
      previewAspectRatio: isPhone ? 9 / 16 : 16 / 9,
      label: switch (deviceClass) {
        DeviceViewportClass.phone => '640x1136 power save',
        DeviceViewportClass.tablet => '960x540 power save',
        DeviceViewportClass.desktop => '960x540 power save',
      },
    );
  }

  static VideoProfile adaptive({
    required double screenWidth,
    required double screenHeight,
    required StreamViewportRole role,
    required VideoQualityPreset preset,
  }) {
    final deviceClass = DeviceViewportClassResolver.fromViewport(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    final isPhone = deviceClass == DeviceViewportClass.phone;
    final previewAspectRatio = isPhone ? 9 / 16 : 16 / 9;

    if (role == StreamViewportRole.camera) {
      if (preset == VideoQualityPreset.dataSaver) {
        return VideoProfile(
          width: isPhone ? 540 : 960,
          height: isPhone ? 960 : 540,
          frameRate: 18,
          previewAspectRatio: previewAspectRatio,
          label: isPhone ? '540x960 saver' : '960x540 saver',
        );
      }
      if (preset == VideoQualityPreset.balanced) {
        return VideoProfile(
          width: isPhone ? 720 : 1280,
          height: isPhone ? 1280 : 720,
          frameRate: 24,
          previewAspectRatio: previewAspectRatio,
          label: isPhone ? '720x1280 balanced' : '1280x720 balanced',
        );
      }
      if (preset == VideoQualityPreset.high) {
        return VideoProfile(
          width: isPhone ? 1080 : 1920,
          height: isPhone ? 1920 : 1080,
          frameRate: 30,
          previewAspectRatio: previewAspectRatio,
          label: isPhone ? '1080x1920 high' : '1920x1080 high',
        );
      }

      return VideoProfile(
        width: isPhone ? 1080 : 1920,
        height: isPhone ? 1920 : 1080,
        frameRate: isPhone ? 24 : 30,
        previewAspectRatio: previewAspectRatio,
        label: switch (deviceClass) {
          DeviceViewportClass.phone => '1080x1920 phone',
          DeviceViewportClass.tablet => '1920x1080 tablet',
          DeviceViewportClass.desktop => '1920x1080 desktop',
        },
      );
    }

    return VideoProfile(
      width: 0,
      height: 0,
      frameRate: 0,
      previewAspectRatio: previewAspectRatio,
      label: switch (deviceClass) {
        DeviceViewportClass.phone => '1080x1920 phone',
        DeviceViewportClass.tablet => '1920x1080 tablet',
        DeviceViewportClass.desktop => '1920x1080 desktop',
      },
    );
  }
}

class StreamSettings {
  static const Object _recordingDirectorySentinel = Object();

  const StreamSettings({
    this.preferDirectP2P = true,
    this.enableTurnFallback = true,
    this.useMultipleStunServers = true,
    this.powerSaveMode = false,
    this.automaticPowerSavingMode = false,
    this.enableMicrophone = false,
    this.maxVideoBitrateKbps = 1200,
    this.lowLightBoost = true,
    this.showConnectionReport = true,
    this.exposureMode = ExposureMode.balanced,
    this.cameraLightMode = CameraLightMode.day,
    this.activityDetectionEnabled = false,
    this.enableMonitorAudio = true,
    this.autoFullscreenOnConnect = false,
    this.viewerPriority = ViewerPriorityMode.balanced,
    this.videoDisplayMode,
    this.videoQualityPreset = VideoQualityPreset.auto,
    this.recordingDirectoryMode = RecordingDirectoryMode.documents,
    this.customRecordingDirectoryPath,
    this.videoProfile = const VideoProfile(
      width: 960,
      height: 540,
      frameRate: 24,
      previewAspectRatio: 9 / 16,
      label: '540p mobile',
    ),
  });

  final bool preferDirectP2P;
  final bool enableTurnFallback;
  final bool useMultipleStunServers;
  final bool powerSaveMode;
  final bool automaticPowerSavingMode;
  final bool enableMicrophone;
  final int maxVideoBitrateKbps;
  final bool lowLightBoost;
  final bool showConnectionReport;
  final ExposureMode exposureMode;
  final CameraLightMode cameraLightMode;
  final bool activityDetectionEnabled;
  final bool enableMonitorAudio;
  final bool autoFullscreenOnConnect;
  final ViewerPriorityMode viewerPriority;
  final VideoDisplayMode? videoDisplayMode;
  final VideoQualityPreset videoQualityPreset;
  final RecordingDirectoryMode recordingDirectoryMode;
  final String? customRecordingDirectoryPath;
  final VideoProfile videoProfile;

  static const cameraDefaults = StreamSettings();
  static const monitorDefaults = StreamSettings(
    lowLightBoost: false,
    videoProfile: VideoProfile(
      width: 0,
      height: 0,
      frameRate: 0,
      previewAspectRatio: 16 / 10,
      label: 'Tablet monitor',
    ),
  );

  StreamSettings copyWith({
    bool? preferDirectP2P,
    bool? enableTurnFallback,
    bool? useMultipleStunServers,
    bool? powerSaveMode,
    bool? automaticPowerSavingMode,
    bool? enableMicrophone,
    int? maxVideoBitrateKbps,
    bool? lowLightBoost,
    bool? showConnectionReport,
    ExposureMode? exposureMode,
    CameraLightMode? cameraLightMode,
    bool? activityDetectionEnabled,
    bool? enableMonitorAudio,
    bool? autoFullscreenOnConnect,
    ViewerPriorityMode? viewerPriority,
    VideoDisplayMode? videoDisplayMode,
    VideoQualityPreset? videoQualityPreset,
    RecordingDirectoryMode? recordingDirectoryMode,
    Object? customRecordingDirectoryPath = _recordingDirectorySentinel,
    VideoProfile? videoProfile,
  }) {
    return StreamSettings(
      preferDirectP2P: preferDirectP2P ?? this.preferDirectP2P,
      enableTurnFallback: enableTurnFallback ?? this.enableTurnFallback,
      useMultipleStunServers:
          useMultipleStunServers ?? this.useMultipleStunServers,
      powerSaveMode: powerSaveMode ?? this.powerSaveMode,
      automaticPowerSavingMode:
          automaticPowerSavingMode ?? this.automaticPowerSavingMode,
      enableMicrophone: enableMicrophone ?? this.enableMicrophone,
      maxVideoBitrateKbps: maxVideoBitrateKbps ?? this.maxVideoBitrateKbps,
      lowLightBoost: lowLightBoost ?? this.lowLightBoost,
      showConnectionReport: showConnectionReport ?? this.showConnectionReport,
      exposureMode: exposureMode ?? this.exposureMode,
      cameraLightMode: cameraLightMode ?? this.cameraLightMode,
      activityDetectionEnabled:
          activityDetectionEnabled ?? this.activityDetectionEnabled,
      enableMonitorAudio: enableMonitorAudio ?? this.enableMonitorAudio,
      autoFullscreenOnConnect:
          autoFullscreenOnConnect ?? this.autoFullscreenOnConnect,
      viewerPriority: viewerPriority ?? this.viewerPriority,
      videoDisplayMode: videoDisplayMode ?? this.videoDisplayMode,
      videoQualityPreset: videoQualityPreset ?? this.videoQualityPreset,
      recordingDirectoryMode:
          recordingDirectoryMode ?? this.recordingDirectoryMode,
      customRecordingDirectoryPath: identical(
        customRecordingDirectoryPath,
        _recordingDirectorySentinel,
      )
          ? this.customRecordingDirectoryPath
          : customRecordingDirectoryPath as String?,
      videoProfile: videoProfile ?? this.videoProfile,
    );
  }

  RTCVideoViewObjectFit get rtcVideoFit =>
      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;

  StreamSettings resolvedForViewport({
    required double screenWidth,
    required double screenHeight,
    required StreamViewportRole role,
  }) {
    final deviceClass = DeviceViewportClassResolver.fromViewport(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    final resolvedDisplayMode = videoDisplayMode ??
        (deviceClass == DeviceViewportClass.phone
            ? VideoDisplayMode.portrait
            : VideoDisplayMode.landscape);
    final resolvedAspectRatio =
        resolvedDisplayMode == VideoDisplayMode.landscape ? 16 / 9 : 9 / 16;

    final resolvedProfile = role == StreamViewportRole.camera && powerSaveMode
        ? VideoProfile.powerSaveFor(deviceClass)
        : VideoProfile.adaptive(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            role: role,
            preset: videoQualityPreset,
          );

    return copyWith(
      enableMicrophone: role == StreamViewportRole.camera && powerSaveMode
          ? false
          : enableMicrophone,
      maxVideoBitrateKbps: role == StreamViewportRole.camera && powerSaveMode
          ? math.min(maxVideoBitrateKbps, 450)
          : maxVideoBitrateKbps,
      lowLightBoost: role == StreamViewportRole.camera && powerSaveMode
          ? false
          : lowLightBoost,
      viewerPriority: role == StreamViewportRole.camera && powerSaveMode
          ? ViewerPriorityMode.balanced
          : viewerPriority,
      videoDisplayMode: resolvedDisplayMode,
      videoQualityPreset: role == StreamViewportRole.camera && powerSaveMode
          ? VideoQualityPreset.dataSaver
          : videoQualityPreset,
      videoProfile: resolvedProfile.copyWith(
        previewAspectRatio: resolvedAspectRatio,
      ),
    );
  }

  String get bitrateLabel => '$maxVideoBitrateKbps kbps';
  String get videoProfileLabel => videoProfile.label;
  String get videoDisplayLabel {
    switch (videoDisplayMode) {
      case VideoDisplayMode.landscape:
        return 'Desktop View';
      case VideoDisplayMode.portrait:
        return 'Mobile View';
      case null:
        return 'Device default';
    }
  }

  String get qualityPresetLabel {
    switch (videoQualityPreset) {
      case VideoQualityPreset.auto:
        return 'Auto';
      case VideoQualityPreset.dataSaver:
        return 'Data saver';
      case VideoQualityPreset.balanced:
        return 'Balanced';
      case VideoQualityPreset.high:
        return 'High';
    }
  }

  bool get hasCustomRecordingDirectory =>
      customRecordingDirectoryPath?.trim().isNotEmpty ?? false;

  String get recordingLocationLabel {
    switch (recordingDirectoryMode) {
      case RecordingDirectoryMode.documents:
        return 'Documents';
      case RecordingDirectoryMode.appSupport:
        return 'App storage';
      case RecordingDirectoryMode.temporary:
        return 'Temporary';
      case RecordingDirectoryMode.custom:
        return 'Custom folder';
    }
  }

  String get recordingLocationDescription {
    switch (recordingDirectoryMode) {
      case RecordingDirectoryMode.documents:
        return 'Store recordings in the device documents area.';
      case RecordingDirectoryMode.appSupport:
        return 'Keep recordings inside the app support folder.';
      case RecordingDirectoryMode.temporary:
        return 'Use temporary storage that the device may clear later.';
      case RecordingDirectoryMode.custom:
        return hasCustomRecordingDirectory
            ? customRecordingDirectoryPath!
            : 'Choose a folder on this device.';
    }
  }
}
