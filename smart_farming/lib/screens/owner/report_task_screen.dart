import 'package:flutter/material.dart';

import '../../services/task_service.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:io';

class ReportTaskScreen extends StatefulWidget {
  final int taskId;
  final List<dynamic> resources;

  const ReportTaskScreen({
    super.key,
    required this.taskId,
    required this.resources,
  });

  @override
  State<ReportTaskScreen> createState() => _ReportTaskScreenState();
}

class _ReportTaskScreenState extends State<ReportTaskScreen> {
  final _notesController = TextEditingController();

  final Map<int, TextEditingController> _resourceControllers = {};
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
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (var controller in _resourceControllers.values) {
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
        title: const Text('Lapor Tugas', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
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
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
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
                              color: Colors.grey,
                            ),
                            Text(
                              'Ambil Bukti Foto',
                              style: TextStyle(color: Colors.grey),
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
                              color: Colors.grey,
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
                backgroundColor: const Color(0xFF2E7D32),
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
