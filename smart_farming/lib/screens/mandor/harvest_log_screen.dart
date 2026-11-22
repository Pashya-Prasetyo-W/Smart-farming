import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/planting_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/rupiah.dart';
import '../../widgets/harvest_form_dialog.dart';

class HarvestLogScreen extends StatefulWidget {
  const HarvestLogScreen({
    super.key,
    required this.plantingId,
    required this.cropName,
    this.plantDate,
  });

  final int plantingId;
  final String cropName;
  final String? plantDate;

  @override
  State<HarvestLogScreen> createState() => _HarvestLogScreenState();
}

class _HarvestLogScreenState extends State<HarvestLogScreen> {
  final _service = PlantingService();

  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  Map<String, dynamic>? _data;
  int? _myId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _myId = prefs.getInt('user_id');
    await _load();
  }

  Future<void> _load() async {
    final result = await _service.harvests(widget.plantingId);
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
    final input = await showDialog<HarvestInput>(
      context: context,
      builder: (_) => HarvestFormDialog(
        firstDate: DateTime.tryParse(widget.plantDate ?? ''),
      ),
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

  String _kg(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '') ?? 0;
    return '${NumberFormat.decimalPattern('id_ID').format(number)} kg';
  }

  Widget _tile(Map<String, dynamic> harvest, bool running) {
    final sold = num.tryParse(harvest['sold_kg'].toString()) ?? 0;
    final price = num.tryParse(harvest['price_per_kg']?.toString() ?? '') ?? 0;
    final recorder = harvest['recorder'];
    final mine = harvest['recorded_by'] == _myId;

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
                    Text('Terjual ${_kg(sold)} x ${Rupiah.format(price)}')
                  else
                    const Text('Belum ada penjualan'),
                  if (recorder is Map)
                    Text(
                      'Dicatat oleh ${recorder['name']}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                ],
              ),
            ),
            if (running && mine)
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
    final running = data != null && data['planting']['status'] == 'berjalan';
    final harvests = ((data?['harvests'] as List?) ?? []);

    return Scaffold(
      appBar: AppBar(title: Text('Panen ${widget.cropName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null || data == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError ?? 'Data tidak tersedia.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _load();
                      },
                      child: const Text('Coba Lagi'),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Total panen'),
                              Text(
                                _kg(data['harvested_kg']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Total terjual'),
                              Text(
                                _kg(data['sold_kg']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Riwayat Panen',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (harvests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('Belum ada hasil panen dicatat.')),
                    )
                  else
                    ...harvests.map((h) => _tile(h as Map<String, dynamic>, running)),
                  if (running) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _recordHarvest,
                      icon: const Icon(Icons.add),
                      label: const Text('CATAT PANEN'),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Siklus sudah ditutup, catatan panen tidak bisa diubah.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
