import 'package:flutter/material.dart';
import '../../services/land_service.dart';

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
        title: const Text('Daftar Lahan', style: TextStyle(color: Colors.white)),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Luas: ${land['area_sqm']} m²'),
                            Text('Koordinat: ${land['location_lat']}, ${land['location_long']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}