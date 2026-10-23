import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/task_service.dart';
import 'report_task_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _task;
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _getUserRole();
  }

  void _fetchDetail() async {
    final data = await TaskService().getTaskDetail(widget.taskId);
    setState(() {
      _task = data;
      _isLoading = false;
    });
  }

  void _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role') ?? '';
    });
  }

  // Fungsi untuk menampilkan Dialog Input Alasan Pembatalan
  void _showCancelDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Batalkan Tugas'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Alasan Pembatalan',
              hintText: 'Contoh: Cuaca buruk, alat rusak...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.isEmpty) return;

                Navigator.pop(dialogContext); // Tutup dialog input

                // Tampilkan loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                bool success = false;
                try {
                  success = await TaskService().cancelTask(
                    widget.taskId,
                    reasonController.text,
                  );
                } catch (e) {
                  print("Error saat cancel: $e");
                } finally {
                  // Pastikan loading tertutup menggunakan rootNavigator
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                }

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tugas berhasil dibatalkan')),
                  );
                  Navigator.pop(context); // Kembali ke list tugas
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal membatalkan tugas. Cek terminal untuk error.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Batalkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _task == null
              ? const Center(child: Text('Gagal memuat detail tugas.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul & Status
                      Text(
                        _task!['title'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${_task!['status'].toString().toUpperCase()}',
                      ),
                      const Divider(height: 32),

                      // Info Lahan
                      const Text(
                        'Lokasi Lahan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(_task!['planting']['land']['name']),
                      const SizedBox(height: 16),

                      // Info Buruh
                      const Text(
                        'Ditugaskan Kepada',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(_task!['assignee']?['name'] ?? 'Belum ada'),
                      const SizedBox(height: 16),

                      // Deskripsi
                      if (_task!['description'] != null) ...[
                        const Text(
                          'Deskripsi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(_task!['description']),
                        const SizedBox(height: 16),
                      ],

                      // Bahan (Resources)
                      const Text(
                        'Bahan yang Dibutuhkan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_task!['resources'] != null &&
                          (_task!['resources'] as List).isNotEmpty)
                        ...(_task!['resources'] as List).map(
                          (res) => Text(
                            '- ${res['name']} (Max: ${res['pivot']['max_allocated_qty']} ${res['unit']})',
                          ),
                        )
                      else
                        const Text('Tidak ada bahan.'),
                      const SizedBox(height: 16),

                      // Alat (Tools)
                      const Text(
                        'Alat yang Dipinjam',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_task!['tools'] != null &&
                          (_task!['tools'] as List).isNotEmpty)
                        ...(_task!['tools'] as List).map(
                          (tool) => Text(
                            '- ${tool['name']} (Qty: ${tool['pivot']['qty']})',
                          ),
                        )
                      else
                        const Text('Tidak ada alat.'),

                      const SizedBox(height: 32),

                      // --- LOGIKA TOMBOL BERDASARKAN ROLE ---

                      // 1. Tombol untuk PEMILIK (Batalkan Tugas)
                      if (_userRole == 'pemilik' &&
                          (_task!['status'] == 'menunggu' ||
                              _task!['status'] == 'dikerjakan'))
                        ElevatedButton(
                          onPressed: _showCancelDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'BATALKAN TUGAS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // 2. Tombol untuk BURUH (Mulai / Lapor)
                      if (_userRole == 'buruh') ...[
                        if (_task!['status'] == 'menunggu')
                          ElevatedButton(
                            onPressed: () async {
                              bool success = await TaskService().startTask(widget.taskId);
                              if (!mounted) return;

                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Pekerjaan dimulai!')),
                                );
                                _fetchDetail(); // Refresh data agar status berubah
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Gagal memulai pekerjaan')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'MULAI KERJAKAN',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (_task!['status'] == 'dikerjakan')
                          ElevatedButton(
                            onPressed: () {
                              // Pindah ke halaman lapor, bawa data resource dari task
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReportTaskScreen(
                                    taskId: widget.taskId,
                                    resources: _task!['resources'] ?? [],
                                  ),
                                ),
                              ).then((_) => _fetchDetail()); // Refresh status setelah lapor
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: const Text('LAPOR SELESAI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}