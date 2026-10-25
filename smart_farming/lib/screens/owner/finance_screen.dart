import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/finance_service.dart';
import '../../services/planting_service.dart';
import '../../utils/currency_formatter.dart';

import 'package:flutter/services.dart';

import '../../services/planting_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Keuangan & HPP',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Riwayat Kas', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Hitung HPP', icon: Icon(Icons.calculate)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_FinanceListTab(), _HppCalculatorTab()],
      ),
    );
  }
}

// --- TAB 1: RIWAYAT KAS ---
class _FinanceListTab extends StatefulWidget {
  @override
  State<_FinanceListTab> createState() => _FinanceListTabState();
}

class _FinanceListTabState extends State<_FinanceListTab> {
  bool _isLoading = true;
  List<dynamic>? _finances;
  List<dynamic> _plantings = [];

  @override
  void initState() {
    super.initState();
    _fetchFinances();
    _fetchPlantings();
  }

  void _fetchPlantings() async {
    final data = await PlantingService().getPlantings();
    setState(() {
      _plantings = (data ?? [])
          .where((p) => p['status'] == 'berjalan')
          .toList();
    });
  }

  void _fetchFinances() async {
    final data = await FinanceService().getFinances();
    setState(() {
      _finances = data;
      _isLoading = false;
    });
  }

  void _showAddFinanceDialog() {
    String type = 'pemasukan';
    int? selectedPlantingId; // <-- Variabel untuk menyimpan pilihan
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Catat Transaksi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'pemasukan',
                        child: Text('Pemasukan (Pendapatan)'),
                      ),
                      DropdownMenuItem(
                        value: 'pengeluaran',
                        child: Text('Pengeluaran (Biaya)'),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => type = val!),
                  ),
                  const SizedBox(height: 12),

                  // --- TAMBAHKAN DROPDOWN PLANTING DI SINI ---
                  DropdownButtonFormField<int?>(
                    value: selectedPlantingId,
                    decoration: const InputDecoration(
                      labelText: 'Kaitkan ke Siklus Tanam',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Biaya Umum (Tanpa Lahan)'),
                      ),
                      ..._plantings.map(
                        (p) => DropdownMenuItem<int?>(
                          value: p['id'] as int,
                          child: Text(
                            '${p['crop_name']} - ${p['land']['name']}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedPlantingId = val),
                  ),
                  const SizedBox(height: 12),
                  // -------------------------------------------

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
                  ),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan (misal: Jual Panen)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final cleanAmount = amountController.text.replaceAll('.', '');
                  final amount = double.tryParse(cleanAmount) ?? 0;

                  if (amount > 0 && descController.text.isNotEmpty) {
                    Navigator.pop(dialogContext);
                    final success = await FinanceService().createFinance({
                      'type': type,
                      'amount': amount,
                      'description': descController.text,
                      'planting_id':
                          selectedPlantingId, // <-- Kirim ID Planting ke API
                    });
                    if (success) {
                      _fetchFinances();
                      _fetchPlantings(); // Refresh data
                    }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_finances == null || _finances!.isEmpty)
      return const Center(child: Text('Belum ada catatan keuangan.'));

    // Hitung Total Pemasukan & Pengeluaran
    double totalIncome = 0;
    double totalExpense = 0;
    for (var f in _finances!) {
      final amount = double.parse(f['amount'].toString());
      if (f['type'] == 'pemasukan') totalIncome += amount;
      if (f['type'] == 'pengeluaran') totalExpense += amount;
    }

    return Scaffold(
      body: Column(
        children: [
          // Ringkasan Kas
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummary('Pemasukan', totalIncome, Colors.green),
                _buildSummary('Pengeluaran', totalExpense, Colors.red),
              ],
            ),
          ),
          // List Transaksi
          Expanded(
            child: ListView.builder(
              itemCount: _finances!.length,
              itemBuilder: (context, index) {
                final f = _finances![index];
                final isIncome = f['type'] == 'pemasukan';
                return ListTile(
                  leading: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                  title: Text(f['description']),
                  subtitle: Text(f['record_date'].toString().substring(0, 10)),
                  trailing: Text(
                    '${isIncome ? "+" : "-"} Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(double.parse(f['amount'].toString()))}',
                    style: TextStyle(
                      color: isIncome ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFinanceDialog,
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummary(String title, double amount, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        Text(
          'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// --- TAB 2: KALKULATOR HPP ---
class _HppCalculatorTab extends StatefulWidget {
  @override
  State<_HppCalculatorTab> createState() => _HppCalculatorTabState();
}

class _HppCalculatorTabState extends State<_HppCalculatorTab> {
  final _harvestController = TextEditingController();
  List<dynamic> _activePlantings = [];
  int? _selectedPlantingId;
  bool _isLoading = true;
  bool _isCalculating = false;

  Map<String, dynamic>? _hppResult;

  @override
  void initState() {
    super.initState();
    _fetchPlantings();
  }

  void _fetchPlantings() async {
    final data = await PlantingService().getPlantings();
    setState(() {
      _activePlantings = (data ?? [])
          .where((p) => p['status'] == 'berjalan')
          .toList();
      if (_activePlantings.isNotEmpty)
        _selectedPlantingId = _activePlantings[0]['id'];
      _isLoading = false;
    });
  }

  void _calculateHpp() async {
    if (_selectedPlantingId == null || _harvestController.text.isEmpty) return;
    setState(() {
      _isCalculating = true;
      _hppResult = null;
    });

    final harvestKg =
        double.tryParse(_harvestController.text.replaceAll('.', '')) ?? 0;
    final result = await FinanceService().calculateHpp(
      _selectedPlantingId!,
      harvestKg,
    );

    setState(() {
      _hppResult = result;
      _isCalculating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_activePlantings.isEmpty)
      return const Center(child: Text('Tidak ada siklus tanam aktif.'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Siklus Tanam',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedPlantingId,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _activePlantings.map<DropdownMenuItem<int>>((p) {
              return DropdownMenuItem<int>(
                value: p['id'],
                child: Text('${p['crop_name']} - ${p['land']['name']}'),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedPlantingId = val),
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Hasil Panen (kg)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _harvestController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // <-- Tambahkan ini
              ThousandsSeparatorInputFormatter(), // <-- Agar muncul titik otomatis
            ],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Contoh: 1.000',
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isCalculating ? null : _calculateHpp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isCalculating
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'HITUNG HPP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),

          if (_hppResult != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Hasil Perhitungan HPP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Biaya Modal:'),
                      Text(
                        'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(_hppResult!['total_cost'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      '(Akumulasi otomatis dari seluruh Riwayat Pengeluaran Kas yang dialokasikan untuk siklus tanam ini)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Hasil Panen:'),
                      Text(
                        '${NumberFormat.decimalPattern('id_ID').format(_hppResult!['harvest_kg'])} kg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const Divider(height: 24, thickness: 2),

                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'HPP per kg',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(_hppResult!['hpp_per_kg'])}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
