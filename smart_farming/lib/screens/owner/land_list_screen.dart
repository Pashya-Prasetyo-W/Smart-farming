import 'package:flutter/material.dart';

import '../../services/land_service.dart';
import 'add_land_screen.dart';
import 'add_planting_screen.dart';
import '../../services/planting_service.dart';

import 'package:intl/intl.dart';

class LandListScreen extends StatefulWidget {
  const LandListScreen({super.key});

  @override
  State<LandListScreen> createState() => _LandListScreenState();
}

class _LandListScreenState extends State<LandListScreen> {
  bool _isLoading = true;
  List<dynamic>? _lands;

  @override
  void initState() {
    super.initState();
    _fetchLands();
  }

  void _fetchLands() async {
    final data = await LandService().getLands();
    setState(() {
      _lands = data;
      _isLoading = false;
    });
  }

  void _showHarvestDialog(int plantingId) {
    final harvestController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Selesaikan Siklus (Panen)'),
        content: TextField(
          controller: harvestController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              final kg = double.tryParse(harvestController.text) ?? 0;
              if (kg <= 0) return;

              Navigator.pop(dialogContext);
              final success = await PlantingService().harvestPlanting(
                plantingId,
                kg,
              );
              if (success) {
                _fetchLands(); // Refresh data lahan
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Siklus berhasil dipanen!')),
                );
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
              if (success) {
                _fetchLands();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Siklus dibatalkan.')),
                );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daftar Lahan',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lands == null || _lands!.isEmpty
          ? const Center(child: Text('Belum ada lahan yang ditambahkan.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lands!.length,
              itemBuilder: (context, index) {
                final land = _lands![index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFC8E6C9),
                      child: Icon(Icons.landscape, color: Color(0xFF2E7D32)),
                    ),
                    title: Text(
                      land['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Luas: ${NumberFormat.decimalPattern('id_ID').format(double.parse(land['area_sqm'].toString()))} m²',
                        ),
                        Text(
                          'Koordinat: ${double.parse(land['location_lat'].toString())}, ${double.parse(land['location_long'].toString())}',
                        ),
                        const SizedBox(height: 8),

                        // CEK APAKAH ADA SIKLUS AKTIF
                        if (land['active_planting'] != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Siklus berjalan: ${land['active_planting']['crop_name']}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // TOMBOL PANEN
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _showHarvestDialog(
                                          land['active_planting']['id'],
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        child: const Text(
                                          'PANEN',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // TOMBOL GAGAL
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _showCancelDialog(
                                          land['active_planting']['id'],
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text(
                                          'GAGAL',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            // ... (Kode tombol Mulai Siklus Tanam biarkan sama) ...
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
                              _fetchLands(); // Refresh jika kembali
                            },
                            icon: const Icon(Icons.eco, size: 16),
                            label: const Text(
                              'Mulai Siklus Tanam',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E7D32),
                            ),
                          ),
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
            MaterialPageRoute(builder: (context) => const AddLandScreen()),
          );
          _fetchLands(); // Refresh list saat kembali
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
