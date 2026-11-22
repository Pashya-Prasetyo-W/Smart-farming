import 'package:flutter/material.dart';

import '../../services/worker_service.dart';
import '../../utils/rupiah.dart';
import 'add_worker_screen.dart';
import 'edit_worker_screen.dart';
import '../../utils/search.dart';
import '../../widgets/search_field.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

class WorkerListScreen extends StatefulWidget {
  const WorkerListScreen({super.key});

  @override
  State<WorkerListScreen> createState() => _WorkerListScreenState();
}

class _WorkerListScreenState extends State<WorkerListScreen> {
  bool _isLoading = true;
  List<dynamic>? _workers;
  String _query = '';

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
    if (type == 'borongan') return 'Borongan (per tugas)';
    final label = type == 'bulanan' ? 'Bulanan' : 'Harian';
    final suffix = type == 'bulanan' ? '/bln' : '/hari';
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
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<dynamic> get _filteredWorkers {
    return (_workers ?? []).where((worker) {
      return matchesSearch(_query, [
        worker['name'],
        worker['email'],
        worker['role'],
        worker['wage_type'],
        worker['is_active'] == false ? 'nonaktif' : null,
        ((worker['benefits'] as List<dynamic>?) ?? []).map((item) => item['name']),
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final workers = _filteredWorkers;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manajemen Karyawan'
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SearchField(
            hint: 'Cari nama, email, peran, tipe upah...',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workers == null || _workers!.isEmpty
          ? const EmptyState(message: 'Belum ada data karyawan.')
          : workers.isEmpty
          ? EmptyState(message: 'Tidak ada hasil untuk "$_query".', icon: Icons.search_off_rounded)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: workers.length,
              itemBuilder: (context, index) {
                final worker = workers[index];
                final schedule = worker['schedule'];
                final List<dynamic> benefits =
                    (worker['benefits'] as List<dynamic>?) ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
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
                                    style: TextStyle(color: AppColors.textMuted),
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
                                              color: AppColors.danger,
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
                                    ? AppColors.textMuted
                                    : AppColors.primary,
                              ),
                              onPressed: () => _toggleActive(worker),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.water),
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
                              icon: const Icon(Icons.delete, color: AppColors.danger),
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
                                      ? AppColors.warning
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
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
