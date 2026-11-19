import 'package:flutter/material.dart';

import '../../services/worker_service.dart';
import '../../utils/rupiah.dart';
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
    if (!mounted) return;
    setState(() {
      _workers = data;
      _isLoading = false;
    });
  }

  Future<void> _toggleActive(Map<String, dynamic> worker) async {
    final makeActive = worker['is_active'] != true;
    final success = await WorkerService().setWorkerActive(
      worker['id'],
      makeActive,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (makeActive ? 'Akun diaktifkan.' : 'Akun dinonaktifkan.')
              : 'Gagal mengubah status akun.',
        ),
      ),
    );
    if (success) _fetchWorkers();
  }

  String _wageLabel(dynamic wage) {
    if (wage is! Map) return 'Upah belum diatur';
    final type = wage['wage_type']?.toString();
    final label = type == 'borongan'
        ? 'Borongan'
        : type == 'bulanan'
        ? 'Bulanan'
        : 'Harian';
    final suffix = type == 'borongan'
        ? '/tugas'
        : type == 'bulanan'
        ? '/bln'
        : '/hari';
    return '$label ${Rupiah.format(wage['amount'])}$suffix';
  }

  num _allowanceTotal(Map<String, dynamic> worker) {
    final allowances = worker['allowances'];
    if (allowances is! List) return 0;
    return allowances.fold<num>(
      0,
      (sum, item) => sum + (num.tryParse(item['amount'].toString()) ?? 0),
    );
  }

  void _showDeleteConfirmation(int id, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text('Apakah Anda yakin ingin menghapus akun $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final result = await WorkerService().deleteWorker(id);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result['message'].toString())),
              );
              if (result['success'] == true) _fetchWorkers();
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
          'Manajemen Karyawan',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workers == null || _workers!.isEmpty
          ? const Center(child: Text('Belum ada data karyawan.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _workers!.length,
              itemBuilder: (context, index) {
                final worker = _workers![index];
                final schedule = worker['schedule'];
                final List<dynamic> benefits =
                    (worker['benefits'] as List<dynamic>?) ?? [];

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
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      Chip(
                                        label: Text(
                                          worker['role'] == 'mandor'
                                              ? 'MANDOR'
                                              : 'BURUH',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      if (worker['is_active'] == false)
                                        const Chip(
                                          label: Text(
                                            'NONAKTIF',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red,
                                            ),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: worker['is_active'] == false
                                  ? 'Aktifkan akun'
                                  : 'Nonaktifkan akun',
                              icon: Icon(
                                worker['is_active'] == false
                                    ? Icons.toggle_off
                                    : Icons.toggle_on,
                                color: worker['is_active'] == false
                                    ? Colors.grey
                                    : const Color(0xFF2E7D32),
                              ),
                              onPressed: () => _toggleActive(worker),
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
                        if (worker.containsKey('wage')) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                avatar: Icon(
                                  Icons.payments,
                                  size: 14,
                                  color: worker['wage'] == null
                                      ? Colors.orange
                                      : null,
                                ),
                                label: Text(
                                  _wageLabel(worker['wage']),
                                  style: const TextStyle(fontSize: 10),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (_allowanceTotal(worker) > 0)
                                Chip(
                                  label: Text(
                                    'Tunjangan ${Rupiah.format(_allowanceTotal(worker))}/bln',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                        if (worker['role'] == 'mandor' &&
                            benefits.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: benefits
                                .map<Widget>(
                                  (item) => Chip(
                                    avatar: Icon(
                                      item['type'] == 'makan'
                                          ? Icons.restaurant
                                          : Icons.health_and_safety,
                                      size: 14,
                                    ),
                                    label: Text(
                                      item['name'].toString(),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah Karyawan',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddWorkerScreen()),
          );
          _fetchWorkers();
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
