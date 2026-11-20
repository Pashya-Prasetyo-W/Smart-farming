import 'package:flutter/material.dart';

import '../../services/payroll_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/rupiah.dart';
import '../../widgets/payroll_status_chip.dart';
import 'payroll_detail_screen.dart';

class PayrollListScreen extends StatefulWidget {
  const PayrollListScreen({super.key});

  @override
  State<PayrollListScreen> createState() => _PayrollListScreenState();
}

class _PayrollListScreenState extends State<PayrollListScreen> {
  final _service = PayrollService();

  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  List<dynamic> _payrolls = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.list();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _loadError = null;
        _payrolls = (result['data'] as List?) ?? [];
      } else {
        _loadError = result['message'].toString();
      }
    });
  }

  Future<void> _create() async {
    if (_isBusy) return;

    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, now.month, 1),
      lastDate: now,
      helpText: 'Pilih periode (dalam satu bulan)',
      saveText: 'Buat',
    );
    if (range == null || !mounted) return;

    setState(() => _isBusy = true);
    final result = await _service.create(apiDate(range.start), apiDate(range.end));
    if (!mounted) return;
    setState(() => _isBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'].toString())),
    );

    if (result['success'] == true) {
      await _load();
      if (!mounted) return;
      _open((result['data'] as Map)['id'] as int);
    }
  }

  void _open(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PayrollDetailScreen(payrollId: id)),
    ).then((_) => _load());
  }

  Widget _tile(Map<String, dynamic> payroll) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(payroll['id'] as int),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatPeriod(payroll['period_start'], payroll['period_end']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  PayrollStatusChip(status: payroll['status']?.toString()),
                ],
              ),
              const SizedBox(height: 4),
              Text('${payroll['items_count'] ?? 0} karyawan'),
              const SizedBox(height: 4),
              Text(
                Rupiah.format(payroll['total_amount']),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Upah')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBusy ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('Buat Rekap'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _load();
                      },
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _payrolls.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Belum ada rekap upah.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: _payrolls.length,
                      itemBuilder: (_, i) =>
                          _tile(_payrolls[i] as Map<String, dynamic>),
                    ),
            ),
    );
  }
}
