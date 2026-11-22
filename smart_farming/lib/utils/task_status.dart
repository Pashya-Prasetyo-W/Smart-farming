import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

String taskStatusLabel(dynamic status) {
  return status.toString().replaceAll('_', ' ').toUpperCase();
}

Color taskStatusColor(dynamic status) {
  switch (status) {
    case 'menunggu':
      return AppColors.warning;
    case 'dikerjakan':
      return AppColors.water;
    case 'menunggu_verifikasi':
      return AppColors.soil;
    case 'selesai':
      return AppColors.primary;
    case 'ditolak':
    case 'batal':
      return AppColors.danger;
    default:
      return AppColors.textMuted;
  }
}
