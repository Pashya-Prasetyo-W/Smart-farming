import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/task_service.dart';
import '../../services/planting_service.dart';
import '../../services/worker_service.dart';
import '../../services/tool_service.dart';
import '../../services/resource_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/rupiah.dart';
import '../../theme/app_theme.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _wageController = TextEditingController();
  DateTime _taskDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));

  bool _isLoading = true;
  bool _isSaving = false;

  List<dynamic> _activePlantings = [];
  List<dynamic> _workers = [];
  List<dynamic> _resources = [];
  List<dynamic> _tools = [];

  int? _selectedPlantingId;
  final Set<int> _selectedWorkerIds = {};

  List<Map<String, dynamic>> _selectedResources = [];
  List<Map<String, dynamic>> _selectedTools = [];

  @override
  void initState() {
    super.initState();
    _fetchReferences();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _wageController.dispose();
    super.dispose();
  }

  int get _boronganCount {
    return _workers
        .where(
          (worker) =>
              _selectedWorkerIds.contains(worker['id']) &&
              worker['wage_type'] == 'borongan',
        )
        .length;
  }

  bool get _isBorongan => _boronganCount > 0;

  bool _isActiveWorker(dynamic worker) => worker['is_active'] != false;

  List<dynamic> get _activeWorkers =>
      _workers.where(_isActiveWorker).toList();

  double _availableOf(dynamic resource) {
    final raw = resource['available_qty'] ?? resource['stock_qty'];
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  void _fetchReferences() async {
    final plantingsData = await PlantingService().getPlantings();
    final workersData = await WorkerService().getWorkers();
    final resourcesData = await ResourceService().getResources();
    final toolsData = await ToolService().getTools();

    if (!mounted) return;

    setState(() {
      _activePlantings = (plantingsData ?? [])
          .where((p) => p['status'] == 'berjalan')
          .toList();
      _workers = workersData ?? [];
      _resources = resourcesData ?? [];
      _tools = toolsData ?? [];
      _isLoading = false;
    });
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _submit() async {
    if (_titleController.text.isEmpty ||
        _selectedPlantingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan Lahan (Siklus) wajib diisi!')),
      );
      return;
    }

    if (_selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu karyawan yang akan ditugaskan.'),
        ),
      );
      return;
    }

    if (_isBorongan && (Rupiah.parse(_wageController.text) ?? 0) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upah tugas wajib diisi untuk pelaksana borongan.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final Map<String, dynamic> data = {
      'planting_id': _selectedPlantingId,
      'assignee_ids': _selectedWorkerIds.toList(),
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'task_date': _formatDate(_taskDate),
      'due_date': _formatDate(_dueDate),
      'resources': _selectedResources,
      'tools': _selectedTools,
      if (_isBorongan) 'wage_amount': Rupiah.parse(_wageController.text),
    };

    final result = await TaskService().createTask(data);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'].toString())));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'].toString()),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showAddResourceDialog() {
    if (_resources.isEmpty) return;
    int? selectedId = _resources[0]['id'];
    final qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedResource = _resources.firstWhere(
            (r) => r['id'] == selectedId,
            orElse: () => _resources[0],
          );

          return AlertDialog(
            title: const Text('Tambah Bahan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedId,
                  items: _resources.map<DropdownMenuItem<int>>((res) {
                    return DropdownMenuItem<int>(
                      value: res['id'],
                      child: Text('${res['name']} (${res['unit']})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),

                Text(
                  'Stok tersedia: ${_availableOf(selectedResource)} ${selectedResource['unit']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Alokasi Max (Qty)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (qtyController.text.isNotEmpty && selectedId != null) {
                    final selectedResource = _resources.firstWhere(
                      (r) => r['id'] == selectedId,
                    );
                    final stockTersedia = _availableOf(selectedResource);
                    final inputQty =
                        double.tryParse(
                          qtyController.text.replaceAll(',', '.'),
                        ) ??
                        0.0;

                    if (inputQty > stockTersedia) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Gagal! Alokasi melebihi stok tersedia ($stockTersedia ${selectedResource['unit']}).',
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      int existingIndex = _selectedResources.indexWhere(
                        (res) => res['resource_id'] == selectedId,
                      );

                      if (existingIndex != -1) {
                        _selectedResources[existingIndex]['max_allocated_qty'] =
                            inputQty;
                      } else {
                        _selectedResources.add({
                          'resource_id': selectedId,
                          'max_allocated_qty': inputQty,
                        });
                      }
                    });
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddToolDialog() {
    if (_tools.isEmpty) return;
    int? selectedId = _tools[0]['id'];
    final qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedTool = _tools.firstWhere(
              (t) => t['id'] == selectedId,
            );
            final availableQty = selectedTool['available_qty'];

            return AlertDialog(
              title: const Text('Tambah Alat'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedId,
                    items: _tools.map<DropdownMenuItem<int>>((tool) {
                      return DropdownMenuItem<int>(
                        value: tool['id'],
                        child: Text(tool['name']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Ketersediaan: $availableQty ${selectedTool['unit_label'] ?? 'buah'}',
                    style: const TextStyle(
                      color: AppColors.water,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty Pinjam',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (qtyController.text.isNotEmpty && selectedId != null) {
                      final availableTersedia =
                          int.tryParse(availableQty.toString()) ?? 0;
                      final inputQty = int.tryParse(qtyController.text) ?? 0;

                      if (inputQty > availableTersedia) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Gagal! Alat yang tersedia hanya $availableTersedia.',
                            ),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        int existingIndex = _selectedTools.indexWhere(
                          (tool) => tool['tool_id'] == selectedId,
                        );

                        if (existingIndex != -1) {
                          _selectedTools[existingIndex]['qty'] = inputQty;
                        } else {
                          _selectedTools.add({
                            'tool_id': selectedId,
                            'qty': inputQty,
                          });
                        }
                      });
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWorkerPicker() {
    final workers = _activeWorkers;
    final allSelected =
        workers.isNotEmpty &&
        workers.every((worker) => _selectedWorkerIds.contains(worker['id']));

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Tugaskan Ke',
        border: OutlineInputBorder(),
      ),
      child: workers.isEmpty
          ? const Text(
              'Belum ada karyawan aktif.',
              style: TextStyle(color: AppColors.danger),
            )
          : Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Pilih semua (${_selectedWorkerIds.length}/${workers.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: allSelected,
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _selectedWorkerIds.addAll(
                        workers.map<int>((worker) => worker['id'] as int),
                      );
                    } else {
                      _selectedWorkerIds.clear();
                    }
                  }),
                ),
                const Divider(height: 1),
                ...workers.map((worker) {
                  final id = worker['id'] as int;
                  final tags = <String>[
                    if (worker['role'] == 'mandor') 'mandor',
                    if (worker['wage_type'] == 'borongan') 'borongan',
                  ];
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      tags.isEmpty
                          ? worker['name'].toString()
                          : '${worker['name']} (${tags.join(', ')})',
                    ),
                    value: _selectedWorkerIds.contains(id),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedWorkerIds.add(id);
                      } else {
                        _selectedWorkerIds.remove(id);
                      }
                    }),
                  );
                }),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buat Tugas Baru'
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Tugas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _activePlantings.isEmpty
                      ? const Text(
                          'Tidak ada siklus tanam aktif. Buat siklus tanam terlebih dahulu!',
                          style: TextStyle(color: AppColors.danger),
                        )
                      : DropdownButtonFormField<int>(
                          value: _selectedPlantingId,
                          decoration: const InputDecoration(
                            labelText: 'Pilih Tanaman (Siklus Aktif)',
                            border: OutlineInputBorder(),
                          ),
                          items: _activePlantings.map<DropdownMenuItem<int>>((
                            planting,
                          ) {
                            return DropdownMenuItem<int>(
                              value: planting['id'],
                              child: Text(
                                '${planting['crop_name']} - ${planting['land']['name']}',
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedPlantingId = val),
                        ),
                  const SizedBox(height: 12),

                  _buildWorkerPicker(),
                  if (_isBorongan) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _wageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Upah Tugas (Borongan)',
                        prefixText: 'Rp ',
                        helperText:
                            'Berlaku untuk setiap pekerja borongan yang dipilih ($_boronganCount orang). Tentukan sesuai tingkat kesulitan dan lama pengerjaan.',
                        helperMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text('Tgl: ${_formatDate(_taskDate)}'),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _taskDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _taskDate = d);
                          },
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.event),
                          label: Text('Deadline: ${_formatDate(_dueDate)}'),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _dueDate,
                              firstDate: _taskDate,
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _dueDate = d);
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bahan (Resource)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddResourceDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                  if (_selectedResources.isEmpty)
                    const Text(
                      'Belum ada bahan dipilih.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else if (_selectedWorkerIds.length > 1)
                    Text(
                      'Jumlah bahan dibagi rata ke ${_selectedWorkerIds.length} tugas.',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ..._selectedResources.map((res) {
                    final resItem = _resources.firstWhere(
                      (r) => r['id'] == res['resource_id'],
                      orElse: () => null,
                    );
                    final resName = resItem != null
                        ? resItem['name']
                        : 'Unknown';
                    return Text(
                      '- $resName (Qty: ${res['max_allocated_qty']})',
                    );
                  }),

                  const Divider(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alat (Tool)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showAddToolDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                  if (_selectedTools.isEmpty)
                    const Text(
                      'Belum ada alat dipinjam.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else if (_selectedWorkerIds.length > 1)
                    Text(
                      'Jumlah alat dibagi rata ke ${_selectedWorkerIds.length} karyawan.',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ..._selectedTools.map((tool) {
                    final toolItem = _tools.firstWhere(
                      (t) => t['id'] == tool['tool_id'],
                      orElse: () => null,
                    );
                    final toolName = toolItem != null
                        ? toolItem['name']
                        : 'Unknown';
                    return Text('- $toolName (Qty: ${tool['qty']})');
                  }),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'BUAT TUGAS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
