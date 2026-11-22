import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/inventory_service.dart';
import '../../services/tool_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/rupiah.dart';
import '../../widgets/inventory_status_chip.dart';
import '../../theme/app_theme.dart';

String incidentKindLabel(String? kind) => kind == 'hilang' ? 'Hilang' : 'Rusak';

String _resolutionLabel(String? resolution) {
  switch (resolution) {
    case 'diperbaiki':
      return 'Diperbaiki';
    case 'ditemukan':
      return 'Ditemukan kembali';
    case 'diganti':
      return 'Diganti baru';
    case 'dihapuskan':
      return 'Dihapuskan dari inventaris';
    default:
      return '-';
  }
}

class IncidentTab extends StatefulWidget {
  const IncidentTab({super.key, required this.isOwner});

  final bool isOwner;

  @override
  State<IncidentTab> createState() => _IncidentTabState();
}

class _IncidentTabState extends State<IncidentTab> {
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
    final result = await _service.incidents();
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

  Future<void> _record() async {
    final tools = await ToolService().getTools();
    if (!mounted) return;

    if (tools == null || tools.isEmpty) {
      _toast('Belum ada alat yang terdaftar.');
      return;
    }

    final message = await showDialog<String>(
      context: context,
      builder: (_) => _RecordDialog(tools: tools),
    );
    if (message == null || !mounted) return;

    _toast(message);
    _load();
  }

  Future<void> _resolve(Map<String, dynamic> item) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _ResolveDialog(incident: item),
    );
    if (message == null || !mounted) return;

    _toast(message);
    _load();
  }

  Widget _tile(Map<String, dynamic> item) {
    final tool = item['tool'] as Map<String, dynamic>?;
    final task = item['task'] as Map<String, dynamic>?;
    final reporter = item['reporter'] as Map<String, dynamic>?;
    final open = item['status'] == 'terbuka';
    final isLost = item['kind'] == 'hilang';
    final color = isLost ? AppColors.danger : AppColors.warning;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLost ? Icons.search_off : Icons.build_circle,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (item['unit_code'] ?? tool?['name'] ?? '-').toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InventoryStatusChip(status: item['status']?.toString()),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              incidentKindLabel(item['kind']?.toString()),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            Text(
              '${formatShortDate(item['created_at'])} • ${reporter?['name'] ?? '-'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (task != null)
              Text(
                'Tugas: ${task['title']}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            if ((item['notes'] ?? '').toString().isNotEmpty)
              Text(
                item['notes'].toString(),
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            if (!open)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Penyelesaian: ${_resolutionLabel(item['resolution']?.toString())}'
                  '${item['resolution_cost'] != null ? ' (${Rupiah.format(item['resolution_cost'])})' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (open && widget.isOwner)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _resolve(item),
                        child: const Text('Selesaikan'),
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
                        Center(child: Text('Belum ada alat rusak atau hilang.')),
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
        heroTag: 'fabIncident',
        backgroundColor: AppColors.warning,
        onPressed: _record,
        icon: const Icon(Icons.report_problem, color: Colors.white),
        label: const Text('Catat Kejadian', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog({required this.tools});

  final List<dynamic> tools;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final _service = InventoryService();
  final _qtyController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  int? _toolId;
  String _kind = 'rusak';
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;

    if (_toolId == null) {
      setState(() => _error = 'Pilih alat terlebih dahulu.');
      return;
    }
    if (qty < 1) {
      setState(() => _error = 'Jumlah minimal 1.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final result = await _service.createIncident({
      'tool_id': _toolId,
      'kind': _kind,
      'qty': qty,
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
    return AlertDialog(
      title: const Text('Catat Alat Rusak / Hilang'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _toolId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Alat'),
              items: widget.tools
                  .map(
                    (t) => DropdownMenuItem<int>(
                      value: t['id'] as int,
                      child: Text(
                        '${t['name']} (tersedia ${t['available_qty']})',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _toolId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Jenis kejadian'),
              items: const [
                DropdownMenuItem(value: 'rusak', child: Text('Rusak')),
                DropdownMenuItem(value: 'hilang', child: Text('Hilang')),
              ],
              onChanged: (value) => setState(() => _kind = value ?? 'rusak'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Jumlah unit'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
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

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.incident});

  final Map<String, dynamic> incident;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _service = InventoryService();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  late String _resolution;
  bool _isSaving = false;
  String? _error;

  List<String> get _options => widget.incident['kind'] == 'hilang'
      ? ['ditemukan', 'diganti', 'dihapuskan']
      : ['diperbaiki', 'diganti', 'dihapuskan'];

  @override
  void initState() {
    super.initState();
    _resolution = _options.first;
  }

  @override
  void dispose() {
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final result = await _service.resolveIncident(
      widget.incident['id'] as int,
      {
        'resolution': _resolution,
        'cost': _resolution == 'dihapuskan'
            ? 0
            : (Rupiah.parse(_costController.text) ?? 0),
        'notes': _notesController.text.trim(),
      },
    );

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
    return AlertDialog(
      title: Text(
        'Selesaikan ${(widget.incident['unit_code'] ?? '').toString()}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _resolution,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Penyelesaian'),
              items: _options
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_resolutionLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _resolution = value ?? _options.first),
            ),
            if (_resolution != 'dihapuskan') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _costController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Biaya (opsional)',
                  prefixText: 'Rp ',
                  helperText: 'Biaya akan dicatat sebagai pengeluaran perawatan alat.',
                  helperMaxLines: 2,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
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
              : const Text('Selesaikan'),
        ),
      ],
    );
  }
}
