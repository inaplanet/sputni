import 'dart:math' as math;

import 'package:flutter_webrtc/flutter_webrtc.dart';

enum ViewerPriorityMode { balanced, smooth, clarity }

enum VideoFitMode { cover, contain }

enum StreamViewportRole { camera, monitor }

enum VideoQualityPreset { auto, dataSaver, balanced, high }

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

  static const cameraPowerSave = VideoProfile(
    width: 640,
    height: 360,
    frameRate: 15,
    previewAspectRatio: 9 / 16,
    label: 'Power save',
  );

  static VideoProfile adaptive({
    required double screenWidth,
    required double screenHeight,
    required StreamViewportRole role,
    required VideoQualityPreset preset,
  }) {
    final shortestSide =
        screenWidth < screenHeight ? screenWidth : screenHeight;
    final longestSide = screenWidth > screenHeight ? screenWidth : screenHeight;
    final isLandscape = screenWidth > screenHeight;
    final isTabletOrDesktop = shortestSide >= 700;
    final isLargeDesktop = longestSide >= 1400;

    if (role == StreamViewportRole.camera) {
      if (preset == VideoQualityPreset.dataSaver) {
        return const VideoProfile(
          width: 640,
          height: 360,
          frameRate: 20,
          previewAspectRatio: 9 / 16,
          label: '360p saver',
        );
      }
      if (preset == VideoQualityPreset.balanced) {
        return const VideoProfile(
          width: 1280,
          height: 720,
          frameRate: 24,
          previewAspectRatio: 4 / 3,
          label: '720p balanced',
        );
      }
      if (preset == VideoQualityPreset.high) {
        return const VideoProfile(
          width: 1920,
          height: 1080,
          frameRate: 30,
          previewAspectRatio: 16 / 10,
          label: '1080p high',
        );
      }

      if (isLargeDesktop) {
        return const VideoProfile(
          width: 1920,
          height: 1080,
          frameRate: 30,
          previewAspectRatio: 16 / 10,
          label: '1080p adaptive',
        );
      }
      if (isTabletOrDesktop || isLandscape) {
        return const VideoProfile(
          width: 1280,
          height: 720,
          frameRate: 24,
          previewAspectRatio: 4 / 3,
          label: '720p adaptive',
        );
      }
      return const VideoProfile(
        width: 960,
        height: 540,
        frameRate: 24,
        previewAspectRatio: 9 / 16,
        label: '540p mobile',
      );
    }

    if (isLargeDesktop) {
      return const VideoProfile(
        width: 0,
        height: 0,
        frameRate: 0,
        previewAspectRatio: 16 / 9,
        label: 'Wide monitor',
      );
    }
    if (isTabletOrDesktop) {
      return const VideoProfile(
        width: 0,
        height: 0,
        frameRate: 0,
        previewAspectRatio: 16 / 10,
        label: 'Tablet monitor',
      );
    }
    return VideoProfile(
      width: 0,
      height: 0,
      frameRate: 0,
      previewAspectRatio: isLandscape ? 16 / 9 : 4 / 5,
      label: 'Compact monitor',
    );
  }
}

class StreamSettings {
  const StreamSettings({
    this.preferDirectP2P = true,
    this.enableTurnFallback = true,
    this.powerSaveMode = false,
    this.enableMicrophone = false,
    this.maxVideoBitrateKbps = 1200,
    this.lowLightBoost = true,
    this.showConnectionReport = true,
    this.viewerPriority = ViewerPriorityMode.balanced,
    this.videoFit = VideoFitMode.cover,
    this.videoQualityPreset = VideoQualityPreset.auto,
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
  final bool powerSaveMode;
  final bool enableMicrophone;
  final int maxVideoBitrateKbps;
  final bool lowLightBoost;
  final bool showConnectionReport;
  final ViewerPriorityMode viewerPriority;
  final VideoFitMode videoFit;
  final VideoQualityPreset videoQualityPreset;
  final VideoProfile videoProfile;

  static const cameraDefaults = StreamSettings();
  static const monitorDefaults = StreamSettings(
    lowLightBoost: false,
    videoFit: VideoFitMode.contain,
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
    bool? powerSaveMode,
    bool? enableMicrophone,
    int? maxVideoBitrateKbps,
    bool? lowLightBoost,
    bool? showConnectionReport,
    ViewerPriorityMode? viewerPriority,
    VideoFitMode? videoFit,
    VideoQualityPreset? videoQualityPreset,
    VideoProfile? videoProfile,
  }) {
    return StreamSettings(
      preferDirectP2P: preferDirectP2P ?? this.preferDirectP2P,
      enableTurnFallback: enableTurnFallback ?? this.enableTurnFallback,
      powerSaveMode: powerSaveMode ?? this.powerSaveMode,
      enableMicrophone: enableMicrophone ?? this.enableMicrophone,
      maxVideoBitrateKbps: maxVideoBitrateKbps ?? this.maxVideoBitrateKbps,
      lowLightBoost: lowLightBoost ?? this.lowLightBoost,
      showConnectionReport: showConnectionReport ?? this.showConnectionReport,
      viewerPriority: viewerPriority ?? this.viewerPriority,
      videoFit: videoFit ?? this.videoFit,
      videoQualityPreset: videoQualityPreset ?? this.videoQualityPreset,
      videoProfile: videoProfile ?? this.videoProfile,
    );
  }

  RTCVideoViewObjectFit get rtcVideoFit {
    switch (videoFit) {
      case VideoFitMode.cover:
        return RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
      case VideoFitMode.contain:
        return RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
    }
  }

  StreamSettings resolvedForViewport({
    required double screenWidth,
    required double screenHeight,
    required StreamViewportRole role,
  }) {
    if (role == StreamViewportRole.camera && powerSaveMode) {
      return copyWith(
        enableMicrophone: false,
        maxVideoBitrateKbps: math.min(maxVideoBitrateKbps, 450),
        lowLightBoost: false,
        viewerPriority: ViewerPriorityMode.balanced,
        videoQualityPreset: VideoQualityPreset.dataSaver,
        videoProfile: VideoProfile.cameraPowerSave,
      );
    }

    return copyWith(
      videoProfile: VideoProfile.adaptive(
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        role: role,
        preset: videoQualityPreset,
      ),
    );
  }

  String get bitrateLabel => '$maxVideoBitrateKbps kbps';
  String get videoProfileLabel => videoProfile.label;

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
}
