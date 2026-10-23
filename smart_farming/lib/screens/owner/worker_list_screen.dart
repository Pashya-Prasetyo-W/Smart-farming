import 'package:flutter/material.dart';

import '../../services/worker_service.dart';
import 'add_worker_screen.dart';
import 'edit_worker_screen.dart';

class WorkerListScreen extends StatefulWidget {
  const WorkerListScreen({super.key});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  bool _isLoading = true;
  List<dynamic>? _workers;

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  void _fetchWorkers() async {
    final data = await WorkerService().getWorkers();
    setState(() {
      _workers = data;
      _isLoading = false;
    });
  }

  void _showDeleteConfirmation(int id, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Buruh'),
        content: Text('Apakah Anda yakin ingin menghapus akun $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              // 1. Tutup dialog DULU
              Navigator.pop(dialogContext);

              // 2. Panggil API hapus
              final success = await WorkerService().deleteWorker(id);

              if (!mounted) return;

              // 3. Jika sukses, refresh list
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Buruh berhasil dihapus.')),
                );
                _fetchWorkers(); // Memanggil ulang API agar list ter-update
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal menghapus buruh.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manajemen Buruh',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workers == null || _workers!.isEmpty
          ? const Center(child: Text('Belum ada data buruh.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workers!.length,
              itemBuilder: (context, index) {
                final worker = _workers![index];
                final schedule = worker['schedule'];
                final benefit = worker['benefit'];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    worker['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    worker['email'],
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EditWorkerScreen(worker: worker),
                                  ),
                                );
                                _fetchWorkers();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirmation(
                                worker['id'],
                                worker['name'],
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (schedule != null) ...[
                          Text(
                            'Jam Kerja: ${schedule['start_time'].toString().substring(0, 5)} - ${schedule['end_time'].toString().substring(0, 5)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if (benefit != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (benefit['health_insurance'] == true)
                                const Chip(
                                  label: Text(
                                    'Jaminan Kesehatan',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                              if (benefit['food_allowance'] == true)
                                const Chip(
                                  label: Text(
                                    'Tunjangan Makan',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddWorkerScreen()),
          );
          _fetchWorkers(); // Refresh list saat kembali
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
