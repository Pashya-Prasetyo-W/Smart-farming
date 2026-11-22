import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PayrollStatusChip extends StatelessWidget {
  const PayrollStatusChip({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;

    switch (status) {
      case 'disetujui':
        label = 'Disetujui';
        color = AppColors.water;
        break;
      case 'dibayar':
        label = 'Dibayar';
        color = AppColors.primary;
        break;
      default:
        label = 'Draf';
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
