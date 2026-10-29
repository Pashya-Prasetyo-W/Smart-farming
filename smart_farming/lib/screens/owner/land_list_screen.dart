import 'package:flutter/material.dart';

import '../../services/land_service.dart';
import 'add_land_screen.dart';
import 'land_detail_screen.dart'; // <-- Pastikan file ini sudah ada

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
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _lands!.length,
              itemBuilder: (context, index) {
                final land = _lands![index];
                return InkWell(
                  onTap: () async {
                    // Pindah ke Detail Lahan dan tunggu hingga kembali untuk melakukan refresh
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LandDetailScreen(land: land),
                      ),
                    );
                    _fetchLands(); // Refresh data saat kembali
                  },
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                          const SizedBox(height: 4),
                          Text(
                            'Koordinat: ${double.parse(land['location_lat'].toString())}, ${double.parse(land['location_long'].toString())}',
                          ),
                          const SizedBox(height: 8),
                          if (land['active_planting'] != null)
                            Text(
                              'Siklus aktif: ${land['active_planting']['crop_name']}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
          _fetchLands();
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
