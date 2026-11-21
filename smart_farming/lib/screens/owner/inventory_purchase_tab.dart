import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/inventory_service.dart';
import '../../services/resource_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/rupiah.dart';
import '../../widgets/inventory_status_chip.dart';
import '../../widgets/reason_dialog.dart';

String _qtyText(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '');
  if (number == null) return value?.toString() ?? '-';
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(2);
}

Future<String?> showPurchaseDialog(
  BuildContext context, {
  required List<dynamic> resources,
  Map<String, dynamic>? preselected,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PurchaseDialog(resources: resources, preselected: preselected),
  );
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({required this.resources, this.preselected});

  final List<dynamic> resources;
  final Map<String, dynamic>? preselected;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final _service = InventoryService();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();

  Map<String, dynamic>? _resource;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _select(widget.preselected);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _select(Map<String, dynamic>? resource) {
    _resource = resource;
    final price = num.tryParse(resource?['unit_price']?.toString() ?? '');
    _priceController.text = price == null ? '' : Rupiah.grouped(price);
  }

  double get _qty =>
      double.tryParse(_qtyController.text.trim().replaceAll(',', '.')) ?? 0;

  int get _price => Rupiah.parse(_priceController.text) ?? 0;

  Future<void> _submit() async {
    if (_resource == null) {
      setState(() => _error = 'Pilih bahan terlebih dahulu.');
      return;
    }
    if (_qty <= 0) {
      setState(() => _error = 'Jumlah pembelian wajib diisi.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final result = await _service.createPurchase({
      'resource_id': _resource!['id'],
      'qty': _qty,
      'unit_price': _price,
      'supplier': _supplierController.text.trim(),
      'notes': _notesController.text.trim(),
    });

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context, result['message'].toString());
    } else {
      setState(() {
        _isSaving = false;
        _error = result['message'].toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = _resource?['unit']?.toString() ?? '';

    return AlertDialog(
      title: const Text('Catat Pembelian Bahan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.preselected != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.preselected!['name'].toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _resource?['id'] as int?,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Bahan'),
                items: widget.resources
                    .map(
                      (r) => DropdownMenuItem<int>(
                        value: r['id'] as int,
                        child: Text('${r['name']} (${r['unit']})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _select(
                    widget.resources.firstWhere((r) => r['id'] == value)
                        as Map<String, dynamic>,
                  );
                }),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Jumlah dibeli',
                suffixText: unit,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsSeparatorInputFormatter(),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Harga per satuan',
                prefixText: 'Rp ',
                suffixText: unit.isEmpty ? null : '/ $unit',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supplierController,
              decoration: const InputDecoration(labelText: 'Pemasok (opsional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Total: ${Rupiah.format((_qty * _price).round())}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFC62828)),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class PurchaseTab extends StatefulWidget {
  const PurchaseTab({super.key, required this.isOwner, required this.userId});

  final bool isOwner;
  final int? userId;

  @override
  State<PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends State<PurchaseTab> {
  final _service = InventoryService();

  bool _isLoading = true;
  String? _loadError;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.purchases();
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

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create() async {
    final resources = await ResourceService().getResources();
    if (!mounted) return;

    if (resources == null || resources.isEmpty) {
      _toast('Belum ada bahan. Pemilik perlu menambahkan bahan terlebih dahulu.');
      return;
    }

    final message = await showPurchaseDialog(context, resources: resources);
    if (message == null || !mounted) return;

    _toast(message);
    _load();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    final result = await action();
    if (!mounted) return;
    _toast(result['message'].toString());
    _load();
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final reason = await askReason(
      context,
      title: 'Tolak Pembelian',
      label: 'Alasan penolakan',
      confirmLabel: 'Tolak',
    );
    if (reason == null) return;
    _run(() => _service.rejectPurchase(item['id'] as int, reason));
  }

  Widget _tile(Map<String, dynamic> item) {
    final status = item['status']?.toString();
    final requester = item['requester'] as Map<String, dynamic>?;
    final isMine = widget.userId != null && requester?['id'] == widget.userId;
    final pending = status == 'menunggu';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['resource_name'].toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InventoryStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_qtyText(item['qty'])} ${item['resource_unit']} x ${Rupiah.format(item['unit_price'])}',
            ),
            Text(
              Rupiah.format(item['total_cost']),
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatWorkDate(item['purchased_at'])} • ${requester?['name'] ?? '-'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if ((item['supplier'] ?? '').toString().isNotEmpty)
              Text(
                'Pemasok: ${item['supplier']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if ((item['notes'] ?? '').toString().isNotEmpty)
              Text(
                item['notes'].toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (status == 'ditolak' &&
                (item['reject_reason'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Alasan ditolak: ${item['reject_reason']}',
                  style: const TextStyle(color: Color(0xFFC62828)),
                ),
              ),
            if (pending && widget.isOwner)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reject(item),
                        child: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            _run(() => _service.approvePurchase(item['id'] as int)),
                        child: const Text('Setujui'),
                      ),
                    ),
                  ],
                ),
              ),
            if (pending && !widget.isOwner && isMine)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _run(() => _service.cancelPurchase(item['id'] as int)),
                        child: const Text('Batalkan Pengajuan'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Belum ada pembelian bahan.')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 88),
                      itemCount: _items.length,
                      itemBuilder: (context, index) =>
                          _tile(_items[index] as Map<String, dynamic>),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fabPurchase',
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: _create,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Catat Pembelian', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
