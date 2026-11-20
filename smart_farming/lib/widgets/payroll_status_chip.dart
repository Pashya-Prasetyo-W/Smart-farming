import 'package:flutter/material.dart';

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
        color = const Color(0xFF1565C0);
        break;
      case 'dibayar':
        label = 'Dibayar';
        color = const Color(0xFF2E7D32);
        break;
      default:
        label = 'Draf';
        color = const Color(0xFF546E7A);
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
