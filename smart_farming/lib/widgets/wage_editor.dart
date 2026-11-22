import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/currency_formatter.dart';
import '../utils/rupiah.dart';
import '../theme/app_theme.dart';

class AllowanceEntry {
  AllowanceEntry({String name = '', String amount = ''})
    : nameController = TextEditingController(text: name),
      amountController = TextEditingController(text: amount);

  factory AllowanceEntry.fromJson(Map<String, dynamic> json) {
    final amount = num.tryParse(json['amount']?.toString() ?? '');
    return AllowanceEntry(
      name: json['name']?.toString() ?? '',
      amount: amount == null ? '' : Rupiah.grouped(amount),
    );
  }

  final TextEditingController nameController;
  final TextEditingController amountController;

  bool get isInvalid {
    return nameController.text.trim().isEmpty ||
        Rupiah.parse(amountController.text) == null;
  }

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class WageDraft {
  WageDraft({this.type = 'harian', String amount = ''})
    : amountController = TextEditingController(text: amount);

  factory WageDraft.fromWorker(Map<String, dynamic> worker) {
    final role = worker['role']?.toString() ?? 'buruh';
    final wage = worker['wage'];
    final amount = wage is Map ? num.tryParse(wage['amount']?.toString() ?? '') : null;

    final draft = WageDraft(
      type: wage is Map
          ? (wage['wage_type']?.toString() ?? defaultType(role))
          : defaultType(role),
      amount: amount == null ? '' : Rupiah.grouped(amount),
    );

    final allowances = worker['allowances'];
    if (allowances is List) {
      for (final item in allowances.whereType<Map>()) {
        draft.allowances.add(
          AllowanceEntry.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    return draft;
  }

  String type;
  final TextEditingController amountController;
  final List<AllowanceEntry> allowances = [];

  static String defaultType(String role) {
    return role == 'mandor' ? 'bulanan' : 'harian';
  }

  void useRole(String role) {
    if (role == 'mandor') {
      type = 'bulanan';
    } else if (type == 'bulanan') {
      type = 'harian';
    }
  }

  bool get hasInvalidAllowance => allowances.any((entry) => entry.isInvalid);

  Map<String, dynamic>? payload() {
    if (type == 'borongan') return {'wage_type': type};
    final amount = Rupiah.parse(amountController.text);
    if (amount == null) return null;
    return {'wage_type': type, 'amount': amount};
  }

  List<Map<String, dynamic>> allowancePayload() {
    return allowances
        .map(
          (entry) => {
            'name': entry.nameController.text.trim(),
            'amount': Rupiah.parse(entry.amountController.text) ?? 0,
          },
        )
        .toList();
  }

  void dispose() {
    amountController.dispose();
    for (final entry in allowances) {
      entry.dispose();
    }
  }
}

class WageEditor extends StatefulWidget {
  const WageEditor({super.key, required this.draft, required this.role});

  final WageDraft draft;
  final String role;

  @override
  State<WageEditor> createState() => _WageEditorState();
}

class _WageEditorState extends State<WageEditor> {
  bool get _isMandor => widget.role == 'mandor';

  String get _amountLabel {
    switch (widget.draft.type) {
      case 'bulanan':
        return 'Gaji Pokok per Bulan';
      default:
        return 'Upah per Hari';
    }
  }

  String? get _amountHelper {
    switch (widget.draft.type) {
      case 'bulanan':
        return 'Gaji tetap, dibayar setiap bulan.';
      default:
        return 'Dibayarkan untuk setiap hari hadir. Boleh dikosongkan dan diisi nanti.';
    }
  }

  void _addAllowance() {
    setState(() => widget.draft.allowances.add(AllowanceEntry()));
  }

  void _removeAllowance(int index) {
    final removed = widget.draft.allowances[index];
    setState(() => widget.draft.allowances.removeAt(index));
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isMandor)
          const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Tipe Upah',
              border: OutlineInputBorder(),
            ),
            child: Text('Bulanan (gaji tetap)'),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey('${widget.role}_${draft.type}'),
            initialValue: draft.type,
            decoration: const InputDecoration(
              labelText: 'Tipe Upah',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'harian', child: Text('Harian')),
              DropdownMenuItem(
                value: 'borongan',
                child: Text('Borongan (upah ditentukan per tugas)'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => draft.type = value);
            },
          ),
        const SizedBox(height: 12),
        if (draft.type == 'borongan')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Tarif borongan tidak diisi di sini. Upah ditentukan pada setiap tugas saat tugas dibuat, sesuai tingkat kesulitan dan lama pengerjaannya.',
            ),
          )
        else
          TextField(
            controller: draft.amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              ThousandsSeparatorInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: _amountLabel,
              prefixText: 'Rp ',
              helperText: _amountHelper,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
        if (_isMandor) ...[
          const SizedBox(height: 16),
          const Text(
            'Tunjangan Tetap Bulanan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (draft.allowances.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Belum ada tunjangan.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          for (var i = 0; i < draft.allowances.length; i++)
            Card(
              key: ObjectKey(draft.allowances[i]),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: draft.allowances[i].nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nama Tunjangan',
                              hintText: 'Contoh: Tunjangan transport',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete, color: AppColors.danger),
                          onPressed: () => _removeAllowance(i),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: draft.allowances[i].amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Nominal per Bulan',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addAllowance,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Tunjangan'),
          ),
        ],
      ],
    );
  }
}
