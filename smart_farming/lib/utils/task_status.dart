import 'package:flutter/material.dart';

String taskStatusLabel(dynamic status) {
  return status.toString().replaceAll('_', ' ').toUpperCase();
}

Color taskStatusColor(dynamic status) {
  switch (status) {
    case 'menunggu':
      return Colors.orange;
    case 'dikerjakan':
      return Colors.blue;
    case 'menunggu_verifikasi':
      return Colors.purple;
    case 'selesai':
      return Colors.green;
    case 'ditolak':
    case 'batal':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
