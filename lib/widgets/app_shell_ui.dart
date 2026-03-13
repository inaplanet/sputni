import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/stream_settings.dart';
import '../ui/azure_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    required this.title,
    required this.subtitle,
    required this.hero,
    required this.panels,
    required this.actions,
    this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget hero;
  final List<Widget> panels;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE6F4FF), Color(0xFFF8FBFF), Color(0xFFD7EBFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: -80,
                left: -30,
                child: _GlowOrb(
                  size: 220,
                  color: Color(0x701279FF),
                ),
              ),
              const Positioned(
                top: 180,
                right: -40,
                child: _GlowOrb(
                  size: 180,
                  color: Color(0x556BD7FF),
                ),
              ),
              const Positioned(
                bottom: -70,
                left: 60,
                child: _GlowOrb(
                  size: 240,
                  color: Color(0x40A6D4FF),
                ),
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  GlassPanel(
                    borderRadius: 30,
                    padding: const EdgeInsets.fromLTRB(14, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: onBack ??
                                  () {
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AzureTheme.ink,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: AzureTheme.ink.withValues(alpha: 0.72),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  hero,
                  const SizedBox(height: 18),
                  ...panels.expand(
                    (panel) => [panel, const SizedBox(height: 14)],
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 640) {
                        return Column(
                          children: actions
                              .map(
                                (action) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: action,
                                ),
                              )
                              .toList(),
                        );
                      }

                      return Row(
                        children: actions
                            .map((action) => Expanded(child: action))
                            .expand(
                              (widget) => [widget, const SizedBox(width: 12)],
                            )
                            .toList()
                          ..removeLast(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding,
    this.borderRadius = 28,
    this.opacity = 0.68,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity),
                Colors.white.withValues(alpha: opacity - 0.14),
              ],
            ),
            border: Border.all(color: AzureTheme.glassStroke),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14081A33),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: GlassPanel(
        padding: padding,
        child: child,
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum MetricTone { neutral, good, warning, danger }

enum SettingsSheetMode { camera, monitor }

class MetricBadge extends StatefulWidget {
  const MetricBadge({
    required this.label,
    required this.icon,
    this.tone = MetricTone.neutral,
    this.monochrome = false,
    this.showLabelByDefault = false,
    this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final MetricTone tone;
  final bool monochrome;
  final bool showLabelByDefault;
  final VoidCallback? onPressed;

  @override
  State<MetricBadge> createState() => _MetricBadgeState();
}

class _MetricBadgeState extends State<MetricBadge>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isTappedOpen = false;

  bool get _isExpanded =>
      widget.showLabelByDefault || (_usesHover ? _isHovered : _isTappedOpen);

  bool get _usesHover {
    switch (Theme.of(context).platform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _metricColors(widget.tone);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _usesHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: _usesHover ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.onPressed ??
            (_usesHover
                ? null
                : () => setState(() => _isTappedOpen = !_isTappedOpen)),
        child: AnimatedContainer(
          alignment: Alignment.center,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: colors.foreground),
                if (_isExpanded) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  _MetricColors _metricColors(MetricTone tone) {
    if (widget.monochrome) {
      return const _MetricColors(
        background: Color(0xBFFFFFFF),
        border: Color(0x99FFFFFF),
        foreground: AzureTheme.azureDark,
      );
    }

    switch (tone) {
      case MetricTone.good:
        return const _MetricColors(
          background: Color(0xBFFFFFFF),
          border: Color(0x99FFFFFF),
          foreground: Color(0xFF157347),
        );
      case MetricTone.warning:
        return const _MetricColors(
          background: Color(0xBFFFFFFF),
          border: Color(0x99FFFFFF),
          foreground: Color(0xFFB56100),
        );
      case MetricTone.danger:
        return const _MetricColors(
          background: Color(0xBFFFFFFF),
          border: Color(0x99FFFFFF),
          foreground: Color(0xFFB42318),
        );
      case MetricTone.neutral:
        return const _MetricColors(
          background: Color(0xBFFFFFFF),
          border: Color(0x99FFFFFF),
          foreground: AzureTheme.azureDark,
        );
    }
  }
}

class ConnectionReportPanel extends StatelessWidget {
  const ConnectionReportPanel({
    required this.title,
    required this.summary,
    required this.highlights,
    required this.statusTone,
    super.key,
  });

  final String title;
  final String summary;
  final List<MetricBadge> highlights;
  final MetricTone statusTone;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AzureTheme.glassStroke),
                ),
                child: const Icon(
                  Icons.network_check_rounded,
                  color: AzureTheme.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AzureTheme.ink.withValues(alpha: 0.78),
                  height: 1.4,
                ),
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: highlights,
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsShortcutPanel extends StatelessWidget {
  const SettingsShortcutPanel({
    required this.shortcuts,
    super.key,
  });

  final List<Widget> shortcuts;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceClass = DeviceViewportClassResolver.fromViewport(
      screenWidth: size.width,
      screenHeight: size.height,
    );

    return SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (deviceClass == DeviceViewportClass.phone) {
            return Column(
              children: shortcuts
                  .map(
                    (shortcut) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(width: double.infinity, child: shortcut),
                    ),
                  )
                  .toList(),
            );
          }

          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: shortcuts,
          );
        },
      ),
    );
  }
}

class _MetricColors {
  const _MetricColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

Future<void> showFullscreenPreview({
  required BuildContext context,
  required RTCVideoRenderer renderer,
  required RTCVideoViewObjectFit objectFit,
  required String profileLabel,
  bool mirror = false,
  bool lowLightBoost = false,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  label: 'Fullscreen video preview',
                  image: true,
                  child: ExcludeSemantics(
                    child: RTCVideoView(
                      renderer,
                      mirror: mirror,
                      objectFit: objectFit,
                    ),
                  ),
                ),
                if (lowLightBoost)
                  Container(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.08),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Text(
                      profileLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

Future<StreamSettings?> showSettingsSheet({
  required BuildContext context,
  required String title,
  required StreamSettings initialSettings,
  required bool turnAvailable,
  SettingsSheetMode mode = SettingsSheetMode.camera,
}) {
  return showModalBottomSheet<StreamSettings>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettingsSheet(
      title: title,
      initialSettings: initialSettings,
      turnAvailable: turnAvailable,
      mode: mode,
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.title,
    required this.initialSettings,
    required this.turnAvailable,
    required this.mode,
  });

  final String title;
  final StreamSettings initialSettings;
  final bool turnAvailable;
  final SettingsSheetMode mode;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late StreamSettings _settings = widget.initialSettings;

  bool get _supportsDirectoryPicker => !kIsWeb;

  void _setPowerSaveMode(bool enabled) {
    setState(() {
      _settings = _settings.copyWith(
        powerSaveMode: enabled,
        enableMicrophone: enabled ? false : _settings.enableMicrophone,
        maxVideoBitrateKbps: enabled && _settings.maxVideoBitrateKbps > 450
            ? 450
            : _settings.maxVideoBitrateKbps,
        lowLightBoost: enabled ? false : _settings.lowLightBoost,
        viewerPriority:
            enabled ? ViewerPriorityMode.balanced : _settings.viewerPriority,
        videoQualityPreset: enabled
            ? VideoQualityPreset.dataSaver
            : _settings.videoQualityPreset,
        videoProfile:
            enabled ? VideoProfile.cameraPowerSave : _settings.videoProfile,
      );
    });
  }

  Future<void> _pickRecordingDirectory() async {
    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose recording folder',
      );

      if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
        return;
      }

      setState(() {
        _settings = _settings.copyWith(
          recordingDirectoryMode: RecordingDirectoryMode.custom,
          customRecordingDirectoryPath: selectedPath.trim(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the folder picker on this device.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCameraMode = widget.mode == SettingsSheetMode.camera;
    final deviceClass = DeviceViewportClassResolver.fromViewport(
      screenWidth: mediaQuery.size.width,
      screenHeight: mediaQuery.size.height,
    );
    final selectedDisplayMode = _settings.videoDisplayMode ??
        (deviceClass == DeviceViewportClass.phone
            ? VideoDisplayMode.portrait
            : VideoDisplayMode.landscape);
    const horizontalPadding = 20.0;
    const verticalPadding = 28.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: GlassPanel(
        borderRadius: 28,
        opacity: 0.78,
        child: SafeArea(
          top: true,
          child: Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: verticalPadding,
              bottom: verticalPadding +
                  mediaQuery.padding.bottom +
                  mediaQuery.viewInsets.bottom,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AzureTheme.azure.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AzureTheme.ink,
                                ),
                          ),
                          const SizedBox(height: 16),
                          SurfacePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('Live Connection'),
                                if (isCameraMode)
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Power save mode'),
                                    subtitle: const Text(
                                        'Lower capture load, cap bitrate, disable mic, and turn off low-light processing to reduce battery use.'),
                                    value: _settings.powerSaveMode,
                                    onChanged: _setPowerSaveMode,
                                  ),
                                if (isCameraMode)
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                        'Automatic power saving mode'),
                                    subtitle: const Text(
                                        'Dim the camera screen after 3 minutes without interaction.'),
                                    value: _settings.automaticPowerSavingMode,
                                    onChanged: (value) => setState(
                                      () => _settings = _settings.copyWith(
                                          automaticPowerSavingMode: value),
                                    ),
                                  ),
                                if (isCameraMode)
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Enable voice'),
                                    subtitle: Text(_settings.powerSaveMode
                                        ? 'Disabled while Power save mode is active.'
                                        : 'Capture microphone audio together with video.'),
                                    value: _settings.powerSaveMode
                                        ? false
                                        : _settings.enableMicrophone,
                                    onChanged: _settings.powerSaveMode
                                        ? null
                                        : (value) => setState(
                                              () => _settings =
                                                  _settings.copyWith(
                                                      enableMicrophone: value),
                                            ),
                                  ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Prefer direct P2P'),
                                  subtitle: const Text(
                                      'Use host and STUN candidates before relay.'),
                                  value: _settings.preferDirectP2P,
                                  onChanged: (value) => setState(
                                    () => _settings = _settings.copyWith(
                                        preferDirectP2P: value),
                                  ),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('TURN fallback'),
                                  subtitle: Text(
                                    widget.turnAvailable
                                        ? 'Only arm relay after direct connection fails.'
                                        : 'TURN server not configured in environment.',
                                  ),
                                  value: _settings.enableTurnFallback &&
                                      widget.turnAvailable,
                                  onChanged: widget.turnAvailable
                                      ? (value) => setState(
                                            () => _settings =
                                                _settings.copyWith(
                                                    enableTurnFallback: value),
                                          )
                                      : null,
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title:
                                      const Text('Use multiple STUN servers'),
                                  subtitle: const Text(
                                      'Cycle between the primary STUN route only or the full STUN server pool.'),
                                  value: _settings.useMultipleStunServers,
                                  onChanged: (value) => setState(
                                    () => _settings = _settings.copyWith(
                                        useMultipleStunServers: value),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SurfacePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('Recording'),
                                Text(
                                  'Save recordings to',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Documents'),
                                      selected:
                                          _settings.recordingDirectoryMode ==
                                              RecordingDirectoryMode.documents,
                                      onSelected: (_) => setState(
                                        () => _settings = _settings.copyWith(
                                          recordingDirectoryMode:
                                              RecordingDirectoryMode.documents,
                                        ),
                                      ),
                                    ),
                                    ChoiceChip(
                                      label: const Text('App storage'),
                                      selected:
                                          _settings.recordingDirectoryMode ==
                                              RecordingDirectoryMode.appSupport,
                                      onSelected: (_) => setState(
                                        () => _settings = _settings.copyWith(
                                          recordingDirectoryMode:
                                              RecordingDirectoryMode.appSupport,
                                        ),
                                      ),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Temporary'),
                                      selected:
                                          _settings.recordingDirectoryMode ==
                                              RecordingDirectoryMode.temporary,
                                      onSelected: (_) => setState(
                                        () => _settings = _settings.copyWith(
                                          recordingDirectoryMode:
                                              RecordingDirectoryMode.temporary,
                                        ),
                                      ),
                                    ),
                                    if (_settings.hasCustomRecordingDirectory)
                                      ChoiceChip(
                                        label: const Text('Custom folder'),
                                        selected:
                                            _settings.recordingDirectoryMode ==
                                                RecordingDirectoryMode.custom,
                                        onSelected: (_) => setState(
                                          () => _settings = _settings.copyWith(
                                            recordingDirectoryMode:
                                                RecordingDirectoryMode.custom,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_supportsDirectoryPicker)
                                  OutlinedButton.icon(
                                    onPressed: _pickRecordingDirectory,
                                    icon: const Icon(
                                      Icons.folder_open_rounded,
                                    ),
                                    label: Text(
                                      _settings.hasCustomRecordingDirectory
                                          ? 'Change custom folder'
                                          : 'Choose custom folder',
                                    ),
                                  ),
                                if (_supportsDirectoryPicker)
                                  const SizedBox(height: 12),
                                Text(
                                  _settings.recordingLocationLabel,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _settings.recordingLocationDescription,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AzureTheme.ink
                                            .withValues(alpha: 0.65),
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (isCameraMode) ...[
                            const SizedBox(height: 12),
                            SurfacePanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionTitle('Video Quality'),
                                  Text('Lower video bitrate',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(
                                    _settings.bitrateLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AzureTheme.ink
                                              .withValues(alpha: 0.65),
                                        ),
                                  ),
                                  Slider(
                                    min: 250,
                                    max: 2500,
                                    divisions: 9,
                                    value: _settings.maxVideoBitrateKbps
                                        .toDouble(),
                                    label: _settings.bitrateLabel,
                                    onChanged: _settings.powerSaveMode
                                        ? null
                                        : (value) => setState(
                                              () => _settings =
                                                  _settings.copyWith(
                                                maxVideoBitrateKbps:
                                                    value.round(),
                                              ),
                                            ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Capture quality',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: VideoQualityPreset.values.map((
                                      preset,
                                    ) {
                                      return ChoiceChip(
                                        label:
                                            Text(_qualityPresetLabel(preset)),
                                        selected:
                                            _settings.videoQualityPreset ==
                                                preset,
                                        onSelected: _settings.powerSaveMode
                                            ? null
                                            : (_) => setState(
                                                  () => _settings =
                                                      _settings.copyWith(
                                                    videoQualityPreset: preset,
                                                  ),
                                                ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Current profile: ${_settings.videoProfileLabel}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AzureTheme.ink
                                              .withValues(alpha: 0.65),
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Low-Light Filter',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: ExposureMode.values.map((mode) {
                                      return ChoiceChip(
                                        label: Text(_exposureModeLabel(mode)),
                                        selected:
                                            _settings.exposureMode == mode,
                                        onSelected: (_) => setState(
                                          () => _settings = _settings.copyWith(
                                            exposureMode: mode,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Camera mode',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        CameraLightMode.values.map((mode) {
                                      return ChoiceChip(
                                        label:
                                            Text(_cameraLightModeLabel(mode)),
                                        selected:
                                            _settings.cameraLightMode == mode,
                                        onSelected: (_) => setState(
                                          () => _settings = _settings.copyWith(
                                            cameraLightMode: mode,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Activity detection'),
                                    subtitle: const Text(
                                        'Detect scene/object movement using live camera motion heuristics.'),
                                    value: _settings.activityDetectionEnabled,
                                    onChanged: (value) => setState(
                                      () => _settings = _settings.copyWith(
                                          activityDetectionEnabled: value),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SurfacePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('Viewer Experience'),
                                Text('Viewer priority',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      ViewerPriorityMode.values.map((mode) {
                                    return ChoiceChip(
                                      label: Text(_viewerPriorityLabel(mode)),
                                      selected:
                                          _settings.viewerPriority == mode,
                                      onSelected: (_) => setState(
                                        () => _settings = _settings.copyWith(
                                            viewerPriority: mode),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                                Text('Video display',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: VideoDisplayMode.values.map((mode) {
                                    return ChoiceChip(
                                      label: Text(
                                        mode == VideoDisplayMode.landscape
                                            ? 'Desktop View'
                                            : 'Mobile View',
                                      ),
                                      selected: selectedDisplayMode == mode,
                                      onSelected: (_) => setState(
                                        () => _settings = _settings.copyWith(
                                            videoDisplayMode: mode),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Connection report'),
                                  subtitle: const Text(
                                      'Show network status card on the dashboard.'),
                                  value: _settings.showConnectionReport,
                                  onChanged: (value) => setState(
                                    () => _settings = _settings.copyWith(
                                        showConnectionReport: value),
                                  ),
                                ),
                                if (!isCameraMode)
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Play camera audio'),
                                    subtitle: const Text(
                                        'Allow monitor mode to play incoming microphone audio from the camera stream.'),
                                    value: _settings.enableMonitorAudio,
                                    onChanged: (value) => setState(
                                      () => _settings = _settings.copyWith(
                                          enableMonitorAudio: value),
                                    ),
                                  ),
                                if (!isCameraMode)
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                        'Auto fullscreen on connect'),
                                    subtitle: const Text(
                                        'Open the live viewer in fullscreen automatically once the secure link becomes active.'),
                                    value: _settings.autoFullscreenOnConnect,
                                    onChanged: (value) => setState(
                                      () => _settings = _settings.copyWith(
                                          autoFullscreenOnConnect: value),
                                    ),
                                  ),
                                if (!isCameraMode)
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Low-light boost'),
                                    subtitle: const Text(
                                        'Apply extra brightness to the incoming monitor preview.'),
                                    value: _settings.lowLightBoost,
                                    onChanged: (value) => setState(
                                      () => _settings = _settings.copyWith(
                                          lowLightBoost: value),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_settings),
                            child: const Text('Apply settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _viewerPriorityLabel(ViewerPriorityMode mode) {
    switch (mode) {
      case ViewerPriorityMode.balanced:
        return 'Balanced';
      case ViewerPriorityMode.smooth:
        return 'Smooth';
      case ViewerPriorityMode.clarity:
        return 'Clarity';
    }
  }

  String _qualityPresetLabel(VideoQualityPreset preset) {
    switch (preset) {
      case VideoQualityPreset.auto:
        return 'Auto';
      case VideoQualityPreset.dataSaver:
        return 'Saver';
      case VideoQualityPreset.balanced:
        return 'Balanced';
      case VideoQualityPreset.high:
        return 'High';
    }
  }

  String _exposureModeLabel(ExposureMode mode) {
    switch (mode) {
      case ExposureMode.high:
        return 'High exposure';
      case ExposureMode.balanced:
        return 'Balanced exposure';
      case ExposureMode.low:
        return 'Low exposure';
    }
  }

  String _cameraLightModeLabel(CameraLightMode mode) {
    switch (mode) {
      case CameraLightMode.day:
        return 'Day mode';
      case CameraLightMode.night:
        return 'Night mode';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AzureTheme.azureDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
