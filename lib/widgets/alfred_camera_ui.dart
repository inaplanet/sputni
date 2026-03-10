import 'package:flutter/material.dart';

import '../config/stream_settings.dart';
import '../ui/azure_theme.dart';

class AlfredShell extends StatelessWidget {
  const AlfredShell({
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
            colors: [Color(0xFFEAF5FF), Colors.white, Color(0xFFD9EFFF)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
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
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AzureTheme.ink,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AzureTheme.ink.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 20),
              hero,
              const SizedBox(height: 20),
              ...panels.expand((panel) => [panel, const SizedBox(height: 16)]),
              Row(
                children: actions
                    .map((action) => Expanded(child: action))
                    .expand((widget) => [widget, const SizedBox(width: 12)])
                    .toList()
                  ..removeLast(),
              ),
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
      child: Padding(
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<StreamSettings?> showAlfredSettingsSheet({
  required BuildContext context,
  required String title,
  required StreamSettings initialSettings,
  required bool turnAvailable,
}) {
  return showModalBottomSheet<StreamSettings>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SettingsSheet(
      title: title,
      initialSettings: initialSettings,
      turnAvailable: turnAvailable,
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.title,
    required this.initialSettings,
    required this.turnAvailable,
  });

  final String title;
  final StreamSettings initialSettings;
  final bool turnAvailable;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late StreamSettings _settings = widget.initialSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: AzureTheme.mist,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: true,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 28,
            bottom: 28 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Prefer direct P2P'),
                        subtitle: const Text(
                            'Use host and STUN candidates before relay.'),
                        value: _settings.preferDirectP2P,
                        onChanged: (value) => setState(
                          () => _settings =
                              _settings.copyWith(preferDirectP2P: value),
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
                                  () => _settings = _settings.copyWith(
                                      enableTurnFallback: value),
                                )
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Video Quality'),
                      Text('Lower video bitrate',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        _settings.bitrateLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AzureTheme.ink.withValues(alpha: 0.65),
                            ),
                      ),
                      Slider(
                        min: 250,
                        max: 2500,
                        divisions: 9,
                        value: _settings.maxVideoBitrateKbps.toDouble(),
                        label: _settings.bitrateLabel,
                        onChanged: (value) => setState(
                          () => _settings = _settings.copyWith(
                            maxVideoBitrateKbps: value.round(),
                          ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Low-light boost'),
                        subtitle: const Text(
                            'Brighten the live preview like AlfredCamera night enhancement.'),
                        value: _settings.lowLightBoost,
                        onChanged: (value) => setState(
                          () => _settings =
                              _settings.copyWith(lowLightBoost: value),
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
                      const _SectionTitle('Detection & Recording'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Activity detection'),
                        subtitle: const Text(
                            'UI-ready toggle for motion/event detection behavior.'),
                        value: _settings.activityDetection,
                        onChanged: (value) => setState(
                          () => _settings =
                              _settings.copyWith(activityDetection: value),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Continuous recording'),
                        subtitle: const Text(
                            'UI-ready toggle for always-on recording workflows.'),
                        value: _settings.continuousRecording,
                        onChanged: (value) => setState(
                          () => _settings =
                              _settings.copyWith(continuousRecording: value),
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
                      const _SectionTitle('Viewer Experience'),
                      Text('Viewer priority',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: ViewerPriorityMode.values.map((mode) {
                          return ChoiceChip(
                            label: Text(_viewerPriorityLabel(mode)),
                            selected: _settings.viewerPriority == mode,
                            onSelected: (_) => setState(
                              () => _settings =
                                  _settings.copyWith(viewerPriority: mode),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text('Video display',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: VideoFitMode.values.map((mode) {
                          return ChoiceChip(
                            label: Text(
                                mode == VideoFitMode.cover ? 'Fill' : 'Fit'),
                            selected: _settings.videoFit == mode,
                            onSelected: (_) => setState(
                              () => _settings =
                                  _settings.copyWith(videoFit: mode),
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
                          () => _settings =
                              _settings.copyWith(showConnectionReport: value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_settings),
                  child: const Text('Apply settings'),
                ),
              ],
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
