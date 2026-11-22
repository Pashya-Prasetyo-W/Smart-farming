import 'package:flutter/material.dart';

import '../../services/task_service.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:io';
import '../../theme/app_theme.dart';

class ReportTaskScreen extends StatefulWidget {
  final int taskId;
  final List<dynamic> resources;
  final List<dynamic> tools;

  const ReportTaskScreen({
    super.key,
    required this.taskId,
    required this.resources,
    this.tools = const [],
  });

  @override
  State<ReportTaskScreen> createState() => _ReportTaskScreenState();
}

class _ReportTaskScreenState extends State<ReportTaskScreen> {
  final _notesController = TextEditingController();

  final Map<int, TextEditingController> _resourceControllers = {};
  final Map<int, TextEditingController> _lostControllers = {};
  final Map<int, TextEditingController> _damagedControllers = {};
  bool _isLoading = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    for (var res in widget.resources) {
      _resourceControllers[res['id']] = TextEditingController();
    }

    for (var tool in widget.tools) {
      _lostControllers[tool['id']] = TextEditingController();
      _damagedControllers[tool['id']] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var controller in _resourceControllers.values) {
      controller.dispose();
    }
    for (var controller in _lostControllers.values) {
      controller.dispose();
    }
    for (var controller in _damagedControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submitReport() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih bukti foto terlebih dahulu!')),
      );
      return;
    }

    final List<Map<String, dynamic>> payloadTools = [];
    for (var tool in widget.tools) {
      final id = tool['id'] as int;
      final lost = int.tryParse(_lostControllers[id]?.text.trim() ?? '') ?? 0;
      final damaged =
          int.tryParse(_damagedControllers[id]?.text.trim() ?? '') ?? 0;
      final borrowed =
          int.tryParse(tool['pivot']?['qty']?.toString() ?? '') ?? 0;

      if (lost + damaged > borrowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Jumlah ${tool['name']} yang hilang dan rusak melebihi yang dipinjam ($borrowed).',
            ),
          ),
        );
        return;
      }

      payloadTools.add({
        'tool_id': id,
        'lost_qty': lost,
        'damaged_qty': damaged,
      });
    }

    setState(() => _isLoading = true);

    String? mediaUrl = await TaskService().uploadFile(_selectedImage!);

    if (mediaUrl == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal mengunggah foto.')));
      return;
    }

    List<Map<String, dynamic>> payloadResources = [];
    for (var res in widget.resources) {
      final id = res['id'] as int;
      final inputStr = _resourceControllers[id]?.text ?? '0';
      final qty = double.tryParse(inputStr) ?? 0.0;
      payloadResources.add({'resource_id': id, 'actual_used_qty': qty});
    }

    final success = await TaskService().submitReportWithUrl(
      widget.taskId,
      payloadResources,
      _notesController.text,
      mediaUrl,
      tools: payloadTools,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan berhasil dikirim!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal mengirim laporan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lapor Tugas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.textMuted),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 40,
                              color: AppColors.textMuted,
                            ),
                            Text(
                              'Ambil Bukti Foto',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Penggunaan Bahan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Masukkan jumlah bahan yang benar-benar terpakai:'),
            const SizedBox(height: 16),

            ...widget.resources.map((res) {
              final id = res['id'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${res['name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Maks: ${res['pivot']['max_allocated_qty']} ${res['unit']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _resourceControllers[id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '0.0',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(res['unit']),
                  ],
                ),
              );
            }),

            if (widget.tools.isNotEmpty) ...[
              const Divider(height: 32),
              const Text(
                'Kondisi Alat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Isi hanya jika ada alat yang hilang atau rusak. Alat lain dianggap kembali dalam kondisi baik.',
              ),
              const SizedBox(height: 16),
              ...widget.tools.map((tool) {
                final id = tool['id'] as int;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tool['name']} (dipinjam ${tool['pivot']?['qty'] ?? '-'})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _lostControllers[id],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Hilang',
                                hintText: '0',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _damagedControllers[id],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Rusak',
                                hintText: '0',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],

            const Divider(height: 32),

            const Text(
              'Catatan Pekerjaan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'KIRIM LAPORAN',
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
