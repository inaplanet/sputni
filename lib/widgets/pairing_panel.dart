import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../ui/azure_theme.dart';

enum PairingMethod { roomId, qrCode }

class PairingPayloadData {
  const PairingPayloadData({
    required this.roomId,
    this.signalingUrl,
    this.role,
  });

  final String roomId;
  final String? signalingUrl;
  final String? role;
}

String buildPairingPayload({
  required String roomId,
  required String signalingUrl,
  required String role,
}) {
  return Uri(
    scheme: 'teleck',
    host: 'pair',
    queryParameters: {
      'room': roomId,
      'signal': signalingUrl,
      'role': role,
    },
  ).toString();
}

PairingPayloadData? parsePairingPayload(String rawValue) {
  final uri = Uri.tryParse(rawValue);
  if (uri == null) return null;
  if (uri.scheme != 'teleck' || uri.host != 'pair') return null;

  final roomId = uri.queryParameters['room'];
  if (roomId == null || roomId.trim().isEmpty) return null;
  final signalingUrl = uri.queryParameters['signal']?.trim();
  final role = uri.queryParameters['role']?.trim();

  return PairingPayloadData(
    roomId: roomId.trim(),
    signalingUrl: signalingUrl == null || signalingUrl.isEmpty
        ? null
        : signalingUrl,
    role: role == null || role.isEmpty ? null : role,
  );
}

String? parseRoomIdFromPairingPayload(String rawValue) {
  return parsePairingPayload(rawValue)?.roomId;
}

class PairingMethodTabs extends StatelessWidget {
  const PairingMethodTabs({
    required this.activeMethod,
    required this.onChanged,
    super.key,
  });

  final PairingMethod activeMethod;
  final ValueChanged<PairingMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AzureTheme.glassStroke),
      ),
      child: Row(
        children: PairingMethod.values.map((method) {
          final isSelected = activeMethod == method;
          final label = method == PairingMethod.roomId ? 'Room ID' : 'QR-Code';
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextButton(
                onPressed: () => onChanged(method),
                style: TextButton.styleFrom(
                  foregroundColor: AzureTheme.ink,
                ),
                child: Text(label),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class PairingQrCodeCard extends StatefulWidget {
  const PairingQrCodeCard({
    required this.payload,
    required this.title,
    required this.subtitle,
    this.showHeader = true,
    super.key,
  });

  final String payload;
  final String title;
  final String subtitle;
  final bool showHeader;

  @override
  State<PairingQrCodeCard> createState() => _PairingQrCodeCardState();
}

class _PairingQrCodeCardState extends State<PairingQrCodeCard> {
  Timer? _copyResetTimer;
  bool _copied = false;

  Future<void> _copyPayload() async {
    await Clipboard.setData(ClipboardData(text: widget.payload));
    _copyResetTimer?.cancel();
    if (!mounted) return;
    setState(() => _copied = true);
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(
                  color: AzureTheme.ink.withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: 16),
        ],
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AzureTheme.glassStroke),
              ),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1 / 2,
                    child: Center(
                      child: Semantics(
                        label: 'Pairing QR code',
                        image: true,
                        child: ExcludeSemantics(
                          child: QrImageView(
                            data: widget.payload,
                            version: QrVersions.auto,
                            backgroundColor: Colors.white,
                            size: 220,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AzureTheme.ink,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AzureTheme.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: OutlinedButton.icon(
                      key: ValueKey(_copied),
                      onPressed: _copyPayload,
                      icon: Icon(
                        _copied ? Icons.check_rounded : Icons.link_rounded,
                      ),
                      label: Text(
                        _copied
                            ? 'Pairing link copied'
                            : 'Copy the pairing link',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showPairingQrCodeModal({
  required BuildContext context,
  required String payload,
  required String title,
  required String subtitle,
}) {
  final screenSize = MediaQuery.of(context).size;
  final horizontalMargin = screenSize.width >= 1024 ? 48.0 : 20.0;
  final verticalMargin = horizontalMargin;

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.36),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: verticalMargin,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AzureTheme.glassStroke),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14081A33),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AzureTheme.ink,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AzureTheme.ink.withValues(alpha: 0.65),
                    ),
              ),
              const SizedBox(height: 16),
              PairingQrCodeCard(
                payload: payload,
                title: title,
                subtitle: subtitle,
                showHeader: false,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
