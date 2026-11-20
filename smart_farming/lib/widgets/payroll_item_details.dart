import 'package:flutter/material.dart';

import '../utils/attendance_format.dart';
import '../utils/rupiah.dart';

String payrollTypeLabel(dynamic type) {
  switch (type) {
    case 'harian':
      return 'Harian';
    case 'borongan':
      return 'Borongan';
    case 'bulanan':
      return 'Bulanan';
    default:
      return 'Belum diatur';
  }
}

List<Widget> payrollItemLines(Map<String, dynamic> item) {
  final type = item['wage_type']?.toString();
  final details = item['details'] is Map
      ? Map<String, dynamic>.from(item['details'] as Map)
      : <String, dynamic>{};
  final lines = <Widget>[];

  Widget row(String left, String right, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(left, style: style)),
          const SizedBox(width: 8),
          Text(right, style: style),
        ],
      ),
    );
  }

  if (type == 'harian') {
    lines.add(
      row(
        '${item['units']} hari × ${Rupiah.format(item['rate'])}',
        Rupiah.format(item['base_amount']),
      ),
    );
    final dates = (details['dates'] as List?) ?? [];
    if (dates.isNotEmpty) {
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            dates.map(formatShortDate).join(', '),
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ),
      );
    }
  } else if (type == 'borongan') {
    final tasks = (details['tasks'] as List?) ?? [];
    for (final task in tasks) {
      lines.add(
        row(task['title']?.toString() ?? '-', Rupiah.format(task['amount'])),
      );
    }
  } else if (type == 'bulanan') {
    if ((item['units'] ?? 0) != 0) {
      lines.add(row('Gaji pokok', Rupiah.format(item['base_amount'])));
      final allowances = (details['allowances'] as List?) ?? [];
      for (final allowance in allowances) {
        lines.add(
          row(
            allowance['name']?.toString() ?? '-',
            Rupiah.format(allowance['amount']),
          ),
        );
      }
    }
  }

  if (item['note'] != null) {
    lines.add(
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          item['note'].toString(),
          style: const TextStyle(color: Color(0xFFEF6C00), fontSize: 12),
        ),
      ),
    );
  }

  lines.add(const Divider(height: 16));
  lines.add(row('Total', Rupiah.format(item['total_amount']), bold: true));

  return lines;
}
