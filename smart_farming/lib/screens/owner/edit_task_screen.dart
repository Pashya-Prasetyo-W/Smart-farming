import 'package:flutter/material.dart';

import '../../services/task_service.dart';
import '../../services/planting_service.dart';
import '../../services/worker_service.dart';
import '../../services/tool_service.dart';
import '../../services/resource_service.dart';

class EditTaskScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _taskDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));

  bool _isLoading = true;
  bool _isSaving = false;

  List<dynamic> _activePlantings = [];
  List<dynamic> _workers = [];
  List<dynamic> _resources = [];
  List<dynamic> _tools = [];

  int? _selectedPlantingId;
  int? _selectedWorkerId;

  List<Map<String, dynamic>> _selectedResources = [];
  List<Map<String, dynamic>> _selectedTools = [];

  @override
  void initState() {
    super.initState();

    _titleController.text = widget.task['title'] ?? '';
    _descController.text = widget.task['description'] ?? '';
    _selectedPlantingId = widget.task['planting_id'];
    _selectedWorkerId = widget.task['assigned_to'];

    _taskDate = DateTime.parse(widget.task['task_date']);
    _dueDate = DateTime.parse(widget.task['due_date']);

    if (widget.task['resources'] != null) {
      for (var res in widget.task['resources']) {
        _selectedResources.add({
          'resource_id': res['id'],
          'max_allocated_qty': double.parse(
            res['pivot']['max_allocated_qty'].toString(),
          ),
        });
      }
    }

    if (widget.task['tools'] != null) {
      for (var tool in widget.task['tools']) {
        _selectedTools.add({
          'tool_id': tool['id'],
          'qty': int.parse(tool['pivot']['qty'].toString()),
        });
      }
    }

    _fetchReferences();
  }

  void _fetchReferences() async {
    final plantingsData = await PlantingService().getPlantings();
    final workersData = await WorkerService().getWorkers();
    final resourcesData = await ResourceService().getResources();
    final toolsData = await ToolService().getTools();

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
        _selectedPlantingId == null ||
        _selectedWorkerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul, Lahan (Siklus), dan Buruh wajib diisi!'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final data = {
      'planting_id': _selectedPlantingId,
      'assigned_to': _selectedWorkerId,
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'task_date': _formatDate(_taskDate),
      'due_date': _formatDate(_dueDate),
      'resources': _selectedResources,
      'tools': _selectedTools,
    };

    final success = await TaskService().updateTask(widget.task['id'], data);

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugas berhasil diperbarui!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui tugas. Cek console.')),
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
                  'Stok tersedia: ${selectedResource['stock_qty']} ${selectedResource['unit']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
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
                    final stockTersedia =
                        double.tryParse(
                          selectedResource['stock_qty'].toString(),
                        ) ??
                        0.0;
                    final inputQty = double.tryParse(qtyController.text) ?? 0.0;

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
                      color: Colors.blue,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Tugas', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
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
                          'Tidak ada siklus tanam aktif.',
                          style: TextStyle(color: Colors.red),
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

                  DropdownButtonFormField<int>(
                    value: _selectedWorkerId,
                    decoration: const InputDecoration(
                      labelText: 'Tugaskan Ke Buruh',
                      border: OutlineInputBorder(),
                    ),
                    items: _workers.map<DropdownMenuItem<int>>((worker) {
                      return DropdownMenuItem<int>(
                        value: worker['id'],
                        child: Text(worker['name']),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedWorkerId = val),
                  ),
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
                      style: TextStyle(color: Colors.grey),
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
                      style: TextStyle(color: Colors.grey),
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
                      backgroundColor: const Color(0xFF2E7D32),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'SIMPAN PERUBAHAN',
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
