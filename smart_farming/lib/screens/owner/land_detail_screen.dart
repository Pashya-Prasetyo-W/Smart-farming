import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../utils/currency_formatter.dart';
import '../../services/planting_service.dart';
import '../../services/land_service.dart';
import '../../services/milestone_service.dart';
import 'add_planting_screen.dart';
import 'edit_land_screen.dart';

class LandDetailScreen extends StatefulWidget {
  final dynamic land;
  const LandDetailScreen({super.key, required this.land});

  @override
  State<LandDetailScreen> createState() => _LandDetailScreenState();
}

class _LandDetailScreenState extends State<LandDetailScreen> {
  final _harvestController = TextEditingController();
  late dynamic _currentLand;
  List<dynamic> _milestones = [];

  @override
  void initState() {
    super.initState();
    _currentLand = widget.land;
    _fetchMilestones();
  }

  void _refreshLand() async {
    final lands = await LandService().getLands();
    if (lands != null && mounted) {
      final updatedLand = lands.firstWhere(
        (l) => l['id'] == _currentLand['id'],
        orElse: () => null,
      );
      if (updatedLand != null) {
        setState(() => _currentLand = updatedLand);
      }
    }
    _fetchMilestones();
  }

  void _fetchMilestones() async {
    final data = await MilestoneService().getMilestones(_currentLand['id']);
    if (mounted) setState(() => _milestones = data ?? []);
  }

  void _showMilestoneDialog({dynamic milestone}) {
    final isEdit = milestone != null;
    final titleController = TextEditingController(
      text: isEdit ? milestone['title'] : '',
    );
    final targetController = TextEditingController(
      text: isEdit
          ? NumberFormat.decimalPattern('id_ID')
                .format(double.parse(milestone['target_value'].toString()))
          : '',
    );
    DateTime deadline = isEdit
        ? DateTime.parse(milestone['deadline'])
        : DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Milestone' : 'Tambah Milestone'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Nama Target'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ThousandsSeparatorInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nilai Target (Angka)',
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: deadline,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => deadline = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Deadline',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('yyyy-MM-dd').format(deadline)),
                        const Icon(Icons.calendar_today, size: 20),
                      ],
                    ),
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
                onPressed: () async {
                  if (titleController.text.isEmpty ||
                      targetController.text.isEmpty)
                    return;
                  final cleanTarget = targetController.text.replaceAll('.', '');
                  final payload = {
                    'title': titleController.text,
                    'target_value': double.tryParse(cleanTarget) ?? 0.0,
                    'deadline': DateFormat('yyyy-MM-dd').format(deadline),
                  };

                  bool success;
                  if (isEdit) {
                    success = await MilestoneService().updateMilestone(
                      milestone['id'],
                      payload,
                    );
                  } else {
                    success = await MilestoneService().createMilestone(
                      _currentLand['id'],
                      payload,
                    );
                  }

                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    if (success) _fetchMilestones();
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateProgressDialog(dynamic milestone) {
    final progressController = TextEditingController(
      text: milestone['current_value'].toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Update Progres: ${milestone['title']}'),
        content: TextField(
          controller: progressController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandsSeparatorInputFormatter(),
          ],
          decoration: const InputDecoration(labelText: 'Nilai Saat Ini'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cleanValue = progressController.text.replaceAll('.', '');
              final newValue = double.tryParse(cleanValue) ?? 0.0;

              Navigator.pop(dialogContext);
              final success = await MilestoneService().updateProgress(
                milestone['id'],
                newValue,
              );
              if (success && mounted) _fetchMilestones();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteMilestone(int milestoneId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Milestone'),
        content: const Text('Apakah Anda yakin ingin menghapus target ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await MilestoneService().deleteMilestone(
                milestoneId,
              );
              if (success && mounted) _fetchMilestones();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCard(dynamic m) {
    final double target = double.parse(m['target_value'].toString());
    final double current = double.parse(m['current_value'].toString());
    final bool isAchieved = current >= target;
    final double progress = target > 0
        ? (current / target).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAchieved ? Colors.green : Colors.grey.shade300,
        ),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          m['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isAchieved)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _showMilestoneDialog(milestone: m);
                    if (value == 'delete') _deleteMilestone(m['id']);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Hapus', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              'Deadline: ${m['deadline'].toString().substring(0, 10)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              color: isAchieved ? Colors.green : Colors.orange,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${NumberFormat.decimalPattern('id_ID').format(current)} / ${NumberFormat.decimalPattern('id_ID').format(target)}',
                  style: const TextStyle(fontSize: 12),
                ),
                TextButton(
                  onPressed: () => _showUpdateProgressDialog(m),
                  child: const Text(
                    'Update Progres',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHarvestDialog(int plantingId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Selesaikan Siklus (Panen)'),
        content: TextField(
          controller: _harvestController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandsSeparatorInputFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: 'Total Hasil Panen (kg)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cleanKg = _harvestController.text.replaceAll('.', '');
              final kg = double.tryParse(cleanKg) ?? 0;
              if (kg <= 0) return;
              Navigator.pop(dialogContext);

              final success = await PlantingService().harvestPlanting(
                plantingId,
                kg,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Siklus berhasil dipanen!')),
                );
                _refreshLand();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(int plantingId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan Siklus'),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan siklus tanam ini? Status akan berubah menjadi GAGAL.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await PlantingService().cancelPlanting(
                plantingId,
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Siklus dibatalkan.')),
                );
                _refreshLand();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final land = _currentLand;
    final activePlanting = land['active_planting'];

    return Scaffold(
      appBar: AppBar(
        title: Text(land['name'], style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditLandScreen(land: land),
                ),
              );
              _refreshLand();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.straighten,
                        color: Color(0xFF2E7D32),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Luas Lahan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${NumberFormat.decimalPattern('id_ID').format(double.parse(land['area_sqm'].toString()))} m²',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.map, color: Color(0xFF2E7D32), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Koordinat Lokasi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${land['location_lat']}, ${land['location_long']}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Target / Milestone',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _showMilestoneDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah'),
                ),
              ],
            ),
            if (_milestones.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Belum ada target untuk lahan ini.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ..._milestones.map((m) => _buildMilestoneCard(m)),

            const SizedBox(height: 24),

            const Text(
              'Status Siklus Tanam',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (activePlanting != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Siklus Berjalan: ${activePlanting['crop_name']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _showHarvestDialog(activePlanting['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text(
                              'PANEN',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _showCancelDialog(activePlanting['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text(
                              'GAGAL',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddPlantingScreen(
                        landId: land['id'],
                        landName: land['name'],
                      ),
                    ),
                  );
                  _refreshLand();
                },
                icon: const Icon(Icons.eco, color: Colors.white),
                label: const Text(
                  'Mulai Siklus Tanam Baru',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
