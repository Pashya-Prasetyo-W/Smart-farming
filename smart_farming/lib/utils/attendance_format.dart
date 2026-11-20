import 'package:flutter/material.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const _dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String two(int value) => value.toString().padLeft(2, '0');

String apiDate(DateTime date) => '${date.year}-${two(date.month)}-${two(date.day)}';

String apiTime(TimeOfDay time) => '${two(time.hour)}:${two(time.minute)}';

String formatWorkDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '-';
  return '${_dayNames[date.weekday - 1]}, ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
}

String formatClock(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '-';
  final local = parsed.toLocal();
  return '${two(local.hour)}:${two(local.minute)}';
}

String statusLabel(String? status) {
  switch (status) {
    case 'terverifikasi':
      return 'Terverifikasi';
    case 'ditolak':
      return 'Ditolak';
    case 'keberatan':
      return 'Keberatan';
    default:
      return 'Menunggu';
  }
}

Color statusColor(String? status) {
  switch (status) {
    case 'terverifikasi':
      return const Color(0xFF2E7D32);
    case 'ditolak':
      return const Color(0xFFC62828);
    case 'keberatan':
      return const Color(0xFFEF6C00);
    default:
      return const Color(0xFF546E7A);
  }
}

String roleLabel(String? role) {
  switch (role) {
    case 'pemilik':
      return 'Pemilik';
    case 'mandor':
      return 'Mandor';
    default:
      return 'Buruh';
  }
}
