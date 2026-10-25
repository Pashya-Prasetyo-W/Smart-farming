import 'package:flutter/material.dart';

import '../../services/resource_service.dart';

import 'package:flutter/services.dart';

import '../../utils/currency_formatter.dart';

class AddResourceScreen extends StatefulWidget {
  const AddResourceScreen({super.key});

  @override
  State<AddResourceScreen> createState() => _AddResourceScreenState();
}

class _AddResourceScreenState extends State<AddResourceScreen> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    if (_nameController.text.isEmpty || _stockController.text.isEmpty) return;
    setState(() => _isLoading = true);

    final priceString = _priceController.text.replaceAll('.', '');
    final unitPrice = double.tryParse(priceString) ?? 0.0;

    final data = {
      'name': _nameController.text.trim(),
      'unit': _unitController.text.trim(),
      'stock_qty': double.tryParse(_stockController.text) ?? 0.0,
      'unit_price': unitPrice,
    };

    final success = await ResourceService().createResource(data);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bahan berhasil ditambahkan!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menambahkan bahan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Bahan'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Bahan (contoh: Pupuk NPK)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Satuan (contoh: kg, liter)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stok Awal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsSeparatorInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Harga Satuan (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'SIMPAN BAHAN',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
