import 'package:flutter/material.dart';

import '../../services/payroll_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/rupiah.dart';
import '../../widgets/payroll_item_details.dart';
import '../../widgets/payroll_status_chip.dart';
import '../../theme/app_theme.dart';

class PayrollDetailScreen extends StatefulWidget {
  const PayrollDetailScreen({super.key, required this.payrollId});

  final int payrollId;

  @override
  State<PayrollDetailScreen> createState() => _PayrollDetailScreenState();
}

class _PayrollDetailScreenState extends State<PayrollDetailScreen> {
  final _service = PayrollService();

  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  Map<String, dynamic>? _payroll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.detail(widget.payrollId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true && result['data'] is Map) {
        _loadError = null;
        _payroll = Map<String, dynamic>.from(result['data'] as Map);
      } else {
        _loadError = result['message'].toString();
      }
    });
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(
    Future<Map<String, dynamic>> Function() action, {
    bool closeOnSuccess = false,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    final result = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'].toString())),
    );

    if (result['success'] != true) return;

    if (closeOnSuccess) {
      Navigator.pop(context);
    } else {
      await _load();
    }
  }

  Future<void> _approve() async {
    final warnings = _payroll?['warnings'] as Map?;
    final pending =
        ((warnings?['pending_attendances'] ?? 0) as num) +
        ((warnings?['pending_reports'] ?? 0) as num);

    final message = pending > 0
        ? 'Masih ada $pending absensi atau laporan yang belum diverifikasi. '
              'Item tersebut tidak ikut dibayar dan akan masuk rekap berikutnya setelah diverifikasi. '
              'Setelah disetujui, rekap tidak dapat diubah lagi.'
        : 'Setelah disetujui, rekap tidak dapat diubah lagi.';

    if (!await _confirm('Setujui rekap upah?', message, 'Setujui')) return;
    await _run(() => _service.approve(widget.payrollId));
  }

  Future<void> _recalculate() async {
    if (!await _confirm(
      'Hitung ulang?',
      'Rekap dihitung ulang dari data absensi dan laporan terverifikasi terbaru.',
      'Hitung ulang',
    )) {
      return;
    }
    await _run(() => _service.recalculate(widget.payrollId));
  }

  Future<void> _pay() async {
    if (!await _confirm(
      'Tandai sudah dibayar?',
      'Pastikan upah sudah diserahkan kepada karyawan.',
      'Tandai dibayar',
    )) {
      return;
    }
    await _run(() => _service.pay(widget.payrollId));
  }

  Future<void> _delete() async {
    if (!await _confirm(
      'Hapus rekap draf?',
      'Absensi dan laporan di dalamnya akan dilepas dan bisa dihitung di rekap lain.',
      'Hapus',
    )) {
      return;
    }
    await _run(() => _service.remove(widget.payrollId), closeOnSuccess: true);
  }

  Widget _warningCard(Map<String, dynamic> payroll) {
    final warnings = payroll['warnings'] as Map?;
    final attendances = (warnings?['pending_attendances'] ?? 0) as num;
    final reports = (warnings?['pending_reports'] ?? 0) as num;

    if (payroll['status'] != 'draf' || (attendances == 0 && reports == 0)) {
      return const SizedBox.shrink();
    }

    return Card(
      color: AppColors.warningSoft,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Belum diverifikasi sampai akhir periode: $attendances absensi dan '
          '$reports laporan kerja. Verifikasi dulu lalu tekan Hitung Ulang '
          'agar ikut terhitung.',
        ),
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> item) {
    final user = item['user'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          '${user?['name'] ?? '-'} (${roleLabel(user?['role']?.toString())})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${payrollTypeLabel(item['wage_type'])} • ${Rupiah.format(item['total_amount'])}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: payrollItemLines(item),
      ),
    );
  }

  Widget _actions(Map<String, dynamic> payroll) {
    final status = payroll['status'];

    if (status == 'draf') {
      return Column(
        children: [
          FilledButton(
            onPressed: _isBusy ? null : _approve,
            child: const Text('Setujui Rekap'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isBusy ? null : _recalculate,
            child: const Text('Hitung Ulang'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isBusy ? null : _delete,
            child: const Text('Hapus Draf'),
          ),
        ],
      );
    }

    if (status == 'disetujui') {
      return FilledButton(
        onPressed: _isBusy ? null : _pay,
        child: const Text('Tandai Sudah Dibayar'),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _body(Map<String, dynamic> payroll) {
    final items = ((payroll['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    final approver = payroll['approver'] as Map?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatPeriod(payroll['period_start'], payroll['period_end']),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              PayrollStatusChip(status: payroll['status']?.toString()),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Rupiah.format(payroll['total_amount']),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          if (approver != null)
            Text('Disetujui oleh ${approver['name']}'),
          if (payroll['paid_at'] != null)
            Text('Dibayar pada ${formatShortDate(payroll['paid_at'])}'),
          const SizedBox(height: 16),
          _warningCard(payroll),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada upah yang dapat direkap pada periode ini.'),
              ),
            )
          else
            ...items.map(_itemTile),
          const SizedBox(height: 16),
          _actions(payroll),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Rekap Upah')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : _body(_payroll!),
    );
  }
}
