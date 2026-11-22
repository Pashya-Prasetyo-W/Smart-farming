import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/attendance_format.dart';
import '../utils/currency_formatter.dart';
import '../utils/rupiah.dart';

class HarvestInput {
  HarvestInput({
    required this.date,
    required this.quantityKg,
    this.soldKg,
    this.pricePerKg,
  });

  final DateTime date;
  final double quantityKg;
  final double? soldKg;
  final double? pricePerKg;
}

class HarvestFormDialog extends StatefulWidget {
  const HarvestFormDialog({this.firstDate});

  final DateTime? firstDate;

  @override
  State<HarvestFormDialog> createState() => HarvestFormDialogState();
}

class HarvestFormDialogState extends State<HarvestFormDialog> {
  final _quantityController = TextEditingController();
  final _soldController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    _soldController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double? _number(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.firstDate ?? now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final quantity = _number(_quantityController.text);
    final sold = _number(_soldController.text) ?? 0;
    final price = Rupiah.parse(_priceController.text)?.toDouble();

    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Jumlah panen wajib diisi.');
      return;
    }
    if (sold > quantity) {
      setState(() => _error = 'Jumlah terjual tidak boleh melebihi jumlah panen.');
      return;
    }
    if (sold > 0 && (price == null || price <= 0)) {
      setState(() => _error = 'Harga jual per kg wajib diisi jika ada yang terjual.');
      return;
    }

    Navigator.pop(
      context,
      HarvestInput(
        date: _date,
        quantityKg: quantity,
        soldKg: sold > 0 ? sold : null,
        pricePerKg: sold > 0 ? price : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Catat Panen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_rounded),
              title: const Text('Tanggal panen'),
              subtitle: Text(formatWorkDate(apiDate(_date))),
              onTap: _pickDate,
            ),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Jumlah panen (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _soldController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Jumlah terjual (kg), opsional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsSeparatorInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Harga jual per kg',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFC62828)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
