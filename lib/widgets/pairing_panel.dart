import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../ui/azure_theme.dart';

enum PairingMethod { roomId, qrCode }

String buildPairingPayload({
  required String roomId,
  required String signalingUrl,
  required String role,
}) {
  return Uri(
    scheme: 'aetherlink',
    host: 'pair',
    queryParameters: {
      'room': roomId,
      'signal': signalingUrl,
      'role': role,
    },
  ).toString();
}

String? parseRoomIdFromPairingPayload(String rawValue) {
  final uri = Uri.tryParse(rawValue);
  if (uri == null) return null;
  if (uri.scheme != 'aetherlink' || uri.host != 'pair') return null;

  final roomId = uri.queryParameters['room'];
  if (roomId == null || roomId.trim().isEmpty) return null;
  return roomId.trim();
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

class PairingQrCodeCard extends StatelessWidget {
  const PairingQrCodeCard({
    required this.payload,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String payload;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(
            context,
          )
              .textTheme
              .bodySmall
              ?.copyWith(color: AzureTheme.ink.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AzureTheme.glassStroke),
          ),
          child: Column(
            children: [
              QrImageView(
                data: payload,
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
              const SizedBox(height: 16),
              SelectableText(
                payload,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
