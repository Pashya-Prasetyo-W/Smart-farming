import 'package:flutter/material.dart';

import '../../services/land_service.dart';
import 'add_land_screen.dart';
import 'add_planting_screen.dart';

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
                              'Luas: ${double.parse(land['area_sqm'].toString()).toStringAsFixed(1)} m²',
                            ),
                            Text(
                              'Koordinat: ${double.parse(land['location_lat'].toString())}, ${double.parse(land['location_long'].toString())}',
                            ),
                            const SizedBox(height: 8),
                            
                            // CEK APAKAH ADA SIKLUS AKTIF
                            if (land['active_planting'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Siklus berjalan: ${land['active_planting']['crop_name']}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else
                              OutlinedButton.icon(
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
                                label: const Text('Mulai Siklus Tanam', style: TextStyle(fontSize: 12)),
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