import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/provider_status_provider.dart';

class ProviderStatusIndicators extends StatelessWidget {
  const ProviderStatusIndicators({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProviderStatusProvider>(
      builder: (context, status, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: 'Global',
              online: status.globalOnline,
              onPressed: () => status.setGlobalOnline(!status.globalOnline),
            ),
            _StatusChip(
              label: 'Uber',
              online: status.isProviderOnline(RideProvider.uber),
              onPressed: () => status.setProviderOnline(
                RideProvider.uber,
                !status.isProviderOnline(RideProvider.uber),
              ),
            ),
            _StatusChip(
              label: 'Lyft',
              online: status.isProviderOnline(RideProvider.lyft),
              onPressed: () => status.setProviderOnline(
                RideProvider.lyft,
                !status.isProviderOnline(RideProvider.lyft),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool online;
  final VoidCallback onPressed;

  const _StatusChip({
    required this.label,
    required this.online,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = online ? Colors.green : Colors.grey;
    final textColor = Theme.of(context).chipTheme.labelStyle?.color;
    return ActionChip(
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      label: Text(
        online ? '$label Online' : '$label Offline',
        style: TextStyle(color: textColor),
      ),
      onPressed: onPressed,
    );
  }
}
