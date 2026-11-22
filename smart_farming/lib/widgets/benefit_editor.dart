import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BenefitEntry {
  BenefitEntry({required this.type, String name = '', String description = ''})
    : nameController = TextEditingController(text: name),
      descriptionController = TextEditingController(text: description);

  factory BenefitEntry.fromJson(Map<String, dynamic> json) {
    return BenefitEntry(
      type: json['type']?.toString() ?? 'kesehatan',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  final String type;
  final TextEditingController nameController;
  final TextEditingController descriptionController;

  static List<BenefitEntry> fromList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => BenefitEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static bool hasBlank(List<BenefitEntry> entries) {
    return entries.any((entry) => entry.nameController.text.trim().isEmpty);
  }

  static List<Map<String, dynamic>> payload(List<BenefitEntry> entries) {
    return entries.map((entry) {
      final description = entry.descriptionController.text.trim();
      return {
        'type': entry.type,
        'name': entry.nameController.text.trim(),
        'description': description.isEmpty ? null : description,
      };
    }).toList();
  }

  static void disposeAll(List<BenefitEntry> entries) {
    for (final entry in entries) {
      entry.dispose();
    }
  }

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
  }
}

class BenefitEditor extends StatefulWidget {
  const BenefitEditor({super.key, required this.entries});

  final List<BenefitEntry> entries;

  @override
  State<BenefitEditor> createState() => _BenefitEditorState();
}

class _BenefitEditorState extends State<BenefitEditor> {
  static const Color _green = AppColors.primary;

  String _typeLabel(String type) {
    return type == 'makan' ? 'Tunjangan Makan' : 'Jaminan Kesehatan';
  }

  String _nameHint(String type) {
    return type == 'makan'
        ? 'Contoh: Uang makan harian'
        : 'Contoh: BPJS Kesehatan';
  }

  IconData _typeIcon(String type) {
    return type == 'makan' ? Icons.restaurant : Icons.health_and_safety;
  }

  void _add(String type) {
    setState(() => widget.entries.add(BenefitEntry(type: type)));
  }

  void _remove(int index) {
    final removed = widget.entries[index];
    setState(() => widget.entries.removeAt(index));
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Belum ada jaminan. Tambahkan sesuai kebutuhan.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        for (var i = 0; i < widget.entries.length; i++)
          Card(
            key: ObjectKey(widget.entries[i]),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(_typeIcon(widget.entries[i].type), color: _green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _typeLabel(widget.entries[i].type),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        onPressed: () => _remove(i),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.entries[i].nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama',
                      hintText: _nameHint(widget.entries[i].type),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.entries[i].descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _add('kesehatan'),
              icon: const Icon(Icons.add),
              label: const Text('Jaminan Kesehatan'),
            ),
            OutlinedButton.icon(
              onPressed: () => _add('makan'),
              icon: const Icon(Icons.add),
              label: const Text('Tunjangan Makan'),
            ),
          ],
        ),
      ],
    );
  }
}
