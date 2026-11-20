import 'package:flutter/material.dart';

import '../../services/payroll_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/rupiah.dart';
import '../../widgets/payroll_item_details.dart';
import '../../widgets/payroll_status_chip.dart';

class MyPayslipScreen extends StatefulWidget {
  const MyPayslipScreen({super.key});

  @override
  State<MyPayslipScreen> createState() => _MyPayslipScreenState();
}

class _MyPayslipScreenState extends State<MyPayslipScreen> {
  final _service = PayrollService();

  bool _isLoading = true;
  String? _loadError;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.mine();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _loadError = null;
        _items = (result['data'] as List?) ?? [];
      } else {
        _loadError = result['message'].toString();
      }
    });
  }

  Widget _tile(Map<String, dynamic> item) {
    final payroll = item['payroll'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          formatPeriod(payroll?['period_start'], payroll?['period_end']),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${payrollTypeLabel(item['wage_type'])} • ${Rupiah.format(item['total_amount'])}',
        ),
        trailing: PayrollStatusChip(status: payroll?['status']?.toString()),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: payrollItemLines(item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Slip Upah Saya')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Belum ada slip upah.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (_, i) =>
                          _tile(_items[i] as Map<String, dynamic>),
                    ),
            ),
    );
  }
}
