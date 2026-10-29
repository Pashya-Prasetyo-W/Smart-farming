import 'package:flutter/material.dart';

import '../../services/planting_service.dart';

class AddPlantingScreen extends StatefulWidget {
  final int landId;
  final String landName;

  const AddPlantingScreen({
    super.key,
    required this.landId,
    required this.landName,
  });

  @override
  State<AddPlantingScreen> createState() => _AddPlantingScreenState();
}

class _AddPlantingScreenState extends State<AddPlantingScreen> {
  final _cropNameController = TextEditingController();
  DateTime _plantDate = DateTime.now();
  DateTime _harvestDate = DateTime.now().add(const Duration(days: 90));
  bool _isLoading = false;

  @override
  void dispose() {
    _cropNameController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _submit() async {
    if (_cropNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama komoditas wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'land_id': widget.landId,
      'crop_name': _cropNameController.text.trim(),
      'plant_date': _formatDate(_plantDate),
      'est_harvest_date': _formatDate(_harvestDate),
    };

    final success = await PlantingService().createPlanting(data);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Siklus Tanam berhasil dimulai!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal membuat siklus tanam. Pastikan lahan belum memiliki siklus aktif.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mulai Siklus Tanam',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Lokasi: ${widget.landName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _cropNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Komoditas (contoh: Cabai Rawit)',
                border: OutlineInputBorder(),
              ),
            ),

            const Divider(height: 32),

            const Text(
              'Tanggal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal Tanam'),
              subtitle: Text(_formatDate(_plantDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _plantDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _plantDate = date);
              },
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Estimasi Panen'),
              subtitle: Text(_formatDate(_harvestDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _harvestDate,
                  firstDate: _plantDate,
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _harvestDate = date);
              },
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'MULAI TANAM',
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
