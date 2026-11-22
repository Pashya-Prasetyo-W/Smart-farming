import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/planting_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/rupiah.dart';
import '../../widgets/harvest_form_dialog.dart';

class PlantingSummaryScreen extends StatefulWidget {
  const PlantingSummaryScreen({super.key, required this.plantingId});

  final int plantingId;

  @override
  State<PlantingSummaryScreen> createState() => _PlantingSummaryScreenState();
}

class _PlantingSummaryScreenState extends State<PlantingSummaryScreen> {
  final _service = PlantingService();

  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.summary(widget.plantingId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        _loadError = null;
        _data = result['data'] as Map<String, dynamic>;
      } else {
        _loadError = result['message'].toString();
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(
    Future<Map<String, dynamic>> Function() action,
    String successMessage,
  ) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    final result = await action();
    if (!mounted) return;

    setState(() => _isBusy = false);
    _toast(
      result['success'] == true ? successMessage : result['message'].toString(),
    );

    if (result['success'] == true) await _load();
  }

  Future<void> _recordHarvest() async {
    final plantDate = DateTime.tryParse(
      _data!['planting']['plant_date'].toString(),
    );

    final input = await showDialog<HarvestInput>(
      context: context,
      builder: (_) => HarvestFormDialog(firstDate: plantDate),
    );
    if (input == null) return;

    await _act(
      () => _service.recordHarvest(
        widget.plantingId,
        harvestDate: apiDate(input.date),
        quantityKg: input.quantityKg,
        soldKg: input.soldKg,
        pricePerKg: input.pricePerKg,
      ),
      'Hasil panen dicatat.',
    );
  }

  Future<void> _deleteHarvest(Map<String, dynamic> harvest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Catatan Panen'),
        content: const Text(
          'Catatan panen dan pemasukan dari penjualannya akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _act(
      () => _service.deleteHarvest(harvest['id'] as int),
      'Catatan panen dihapus.',
    );
  }

  Future<void> _closePlanting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Selesaikan Siklus'),
        content: const Text(
          'Siklus akan ditutup dan tidak bisa menerima catatan panen lagi. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Selesaikan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _act(
      () => _service.closePlanting(widget.plantingId),
      'Siklus diselesaikan.',
    );
  }

  String _kg(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '') ?? 0;
    return '${NumberFormat.decimalPattern('id_ID').format(number)} kg';
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'bahan':
        return 'Bahan';
      case 'upah':
        return 'Upah';
      case 'pembelian':
        return 'Pembelian';
      default:
        return 'Lainnya';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'panen':
        return 'Selesai panen';
      case 'gagal':
        return 'Gagal';
      default:
        return 'Berjalan';
    }
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(Map<String, dynamic> planting) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              planting['crop_name'].toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Lahan: ${planting['land'] ?? '-'}'),
            Text('Status: ${_statusLabel(planting['status'].toString())}'),
            Text('Tanam: ${formatWorkDate(planting['plant_date'])}'),
            if (planting['closed_at'] != null)
              Text('Ditutup: ${formatWorkDate(planting['closed_at'])}'),
          ],
        ),
      ),
    );
  }

  Widget _financeCard(Map<String, dynamic> data) {
    final profit = num.tryParse(data['profit'].toString()) ?? 0;
    final hpp = data['hpp_per_kg'];
    final avg = data['avg_price_per_kg'];
    final costs = (data['costs'] as List?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keuangan Siklus',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...costs.map(
              (cost) => _row(
                'Biaya ${_categoryLabel(cost['category'].toString())}',
                Rupiah.format(cost['amount']),
              ),
            ),
            _row('Total biaya', Rupiah.format(data['total_cost']), bold: true),
            _row('Pendapatan', Rupiah.format(data['income']), bold: true),
            _row(
              profit >= 0 ? 'Laba' : 'Rugi',
              Rupiah.format(profit.abs()),
              color: profit >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              bold: true,
            ),
            const Divider(),
            _row('Total panen', _kg(data['harvested_kg'])),
            _row('Terjual', _kg(data['sold_kg'])),
            _row(
              'Harga jual rata-rata',
              avg == null ? '-' : '${Rupiah.format(avg)} / kg',
            ),
            _row(
              'HPP per kg',
              hpp == null ? '-' : Rupiah.format(hpp),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _harvestTile(Map<String, dynamic> harvest, bool running) {
    final sold = num.tryParse(harvest['sold_kg'].toString()) ?? 0;
    final price = num.tryParse(harvest['price_per_kg']?.toString() ?? '') ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatWorkDate(harvest['harvest_date']),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('Panen ${_kg(harvest['quantity_kg'])}'),
                  if (sold > 0)
                    Text(
                      'Terjual ${_kg(sold)} x ${Rupiah.format(price)} = ${Rupiah.format(sold * price)}',
                    )
                  else
                    const Text('Belum ada penjualan'),
                ],
              ),
            ),
            if (running)
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline),
                onPressed: _isBusy ? null : () => _deleteHarvest(harvest),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan Siklus')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null || data == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError ?? 'Gagal memuat data.', textAlign: TextAlign.center),
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _headerCard(data['planting'] as Map<String, dynamic>),
                  const SizedBox(height: 8),
                  _financeCard(data),
                  const SizedBox(height: 16),
                  const Text(
                    'Riwayat Panen',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (((data['harvests'] as List?) ?? []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('Belum ada hasil panen dicatat.')),
                    )
                  else
                    ...(data['harvests'] as List).map(
                      (h) => _harvestTile(
                        h as Map<String, dynamic>,
                        data['planting']['status'] == 'berjalan',
                      ),
                    ),
                  if (data['planting']['status'] == 'berjalan') ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _recordHarvest,
                      icon: const Icon(Icons.add),
                      label: const Text('CATAT PANEN'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _closePlanting,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('SELESAIKAN SIKLUS'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
