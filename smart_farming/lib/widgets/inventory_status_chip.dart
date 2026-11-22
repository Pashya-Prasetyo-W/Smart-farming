import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InventoryStatusChip extends StatelessWidget {
  const InventoryStatusChip({super.key, required this.status});

  final String? status;

  static String label(String? status) {
    switch (status) {
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'dibatalkan':
        return 'Dibatalkan';
      case 'terbuka':
        return 'Terbuka';
      case 'selesai':
        return 'Selesai';
      default:
        return 'Menunggu persetujuan';
    }
  }

  static Color color(String? status) {
    switch (status) {
      case 'disetujui':
      case 'selesai':
        return AppColors.primary;
      case 'ditolak':
        return AppColors.danger;
      case 'dibatalkan':
        return AppColors.textMuted;
      case 'terbuka':
        return AppColors.warning;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = color(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label(status),
        style: TextStyle(
          color: tint,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
