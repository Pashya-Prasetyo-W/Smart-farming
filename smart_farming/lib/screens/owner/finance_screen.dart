import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/finance_service.dart';
import '../../services/planting_service.dart';
import '../../utils/currency_formatter.dart';

import 'package:flutter/services.dart';
import '../../utils/search.dart';
import 'planting_summary_screen.dart';
import '../../widgets/search_field.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

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
          'Keuangan & HPP'
        ),
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

class _FinanceListTab extends StatefulWidget {
  @override
  State<_FinanceListTab> createState() => _FinanceListTabState();
}

class _FinanceListTabState extends State<_FinanceListTab> {
  bool _isLoading = true;
  List<dynamic>? _finances;
  String _query = '';
  List<dynamic> _plantings = [];

  @override
  void initState() {
    super.initState();
    _fetchFinances();
    _fetchPlantings();
  }

  void _fetchPlantings() async {
    final data = await PlantingService().getPlantings();
    if (!mounted) return;
    setState(() {
      _plantings = (data ?? [])
          .where(
            (p) =>
                p['status'] == 'berjalan' ||
                p['status'] == 'panen' ||
                p['status'] == 'gagal',
          )
          .toList();

      _isLoading = false;
    });
  }

  void _fetchFinances() async {
    final data = await FinanceService().getFinances();
    if (!mounted) return;
    setState(() {
      _finances = data;
      _isLoading = false;
    });
  }

  void _showAddFinanceDialog() {
    String type = 'pemasukan';
    int? selectedPlantingId;
    final amountController = TextEditingController();
    final descController = TextEditingController();

    final messenger = ScaffoldMessenger.of(context);

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
                      ..._plantings.map((p) {
                        final dateStr = p['plant_date'].toString().substring(
                          0,
                          10,
                        );
                        final statusLabel = p['status']
                            .toString()
                            .toUpperCase();

                        return DropdownMenuItem<int?>(
                          value: p['id'] as int,
                          child: Text(
                            '${p['crop_name']} - ${p['land']['name']} ($statusLabel, $dateStr)',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedPlantingId = val),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(labelText: 'Jumlah (Rp)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
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
                      'planting_id': selectedPlantingId,
                    });

                    if (!mounted) return;

                    if (success) {
                      _fetchFinances();
                      _fetchPlantings();

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Transaksi berhasil disimpan!'),
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Gagal menyimpan transaksi. Cek koneksi.',
                          ),
                        ),
                      );
                    }
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Jumlah dan Keterangan wajib diisi!'),
                      ),
                    );
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

  List<dynamic> get _filteredFinances {
    return (_finances ?? []).where((f) {
      return matchesSearch(_query, [
        f['description'],
        f['type'],
        f['record_date'],
        f['amount'],
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final finances = _filteredFinances;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: SearchField(
          hint: 'Cari keterangan, jenis, tanggal...',
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_finances == null || _finances!.isEmpty)
          ? const EmptyState(message: 'Belum ada catatan keuangan.')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _summaryCard(
                              'Pemasukan',
                              _calculateTotal('pemasukan'),
                              AppColors.primary,
                              Icons.arrow_downward_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryCard(
                              'Pengeluaran',
                              _calculateTotal('pengeluaran'),
                              AppColors.danger,
                              Icons.arrow_upward_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _stockRow(_stockPurchaseTotal()),
                    ],
                  ),
                ),
                Expanded(
                  child: finances.isEmpty
                      ? EmptyState(message: 'Tidak ada hasil untuk "$_query".', icon: Icons.search_off_rounded)
                      : ListView.builder(
                    itemCount: finances.length,
                    itemBuilder: (context, index) {
                      final f = finances[index];
                      final isIncome = f['type'] == 'pemasukan';
                      return ListTile(
                        leading: Icon(
                          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIncome ? AppColors.primary : AppColors.danger,
                        ),
                        title: Text(f['description']),
                        subtitle: Text(
                          '${f['record_date'].toString().substring(0, 10)}'
                          '${f['category'] == 'pembelian' ? ' • Pembelian stok (belum dihitung sebagai biaya)' : ''}',
                        ),
                        trailing: Text(
                          '${isIncome ? "+" : "-"} Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(double.parse(f['amount'].toString()))}',
                          style: TextStyle(
                            color: isIncome ? AppColors.primary : AppColors.danger,
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
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  double _calculateTotal(String type) {
    if (_finances == null) return 0;
    return _finances!
        .where((f) => f['type'] == type && f['category'] != 'pembelian')
        .fold(0.0, (sum, f) => sum + double.parse(f['amount'].toString()));
  }

  double _stockPurchaseTotal() {
    if (_finances == null) return 0;
    return _finances!
        .where((f) => f['category'] == 'pembelian')
        .fold(0.0, (sum, f) => sum + double.parse(f['amount'].toString()));
  }

  String _rp(double amount) {
    return 'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount)}';
  }

  Widget _summaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _rp(amount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockRow(double amount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.inventory_2_rounded,
              size: 16,
              color: AppColors.soil,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Beli stok (aset, bukan biaya)',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            Text(
              _rp(amount),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    if (!mounted) return;
    setState(() {
      _activePlantings = (data ?? [])
          .where(
            (p) =>
                p['status'] == 'berjalan' ||
                p['status'] == 'panen' ||
                p['status'] == 'gagal',
          )
          .toList();

      if (_activePlantings.isNotEmpty) {
        _selectedPlantingId = _activePlantings[0]['id'];
      }
      _isLoading = false;
    });
  }

  void _calculateHpp() async {
    if (_selectedPlantingId == null) return;
    setState(() {
      _isCalculating = true;
      _hppResult = null;
    });

    final typed = double.tryParse(_harvestController.text.replaceAll('.', ''));
    final result = await FinanceService().calculateHpp(
      _selectedPlantingId!,
      typed != null && typed > 0 ? typed : null,
    );

    if (!mounted) return;

    setState(() {
      _hppResult = result;
      _isCalculating = false;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada hasil panen tercatat. Catat panen atau isi jumlah panen.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_activePlantings.isEmpty)
      return const EmptyState(message: 'Tidak ada siklus tanam aktif.');

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
              final statusLabel = p['status'].toString().toUpperCase();
              final dateStr = p['plant_date'].toString().substring(0, 10);

              return DropdownMenuItem<int>(
                value: p['id'],
                child: Text(
                  '${p['crop_name']} - ${p['land']['name']} ($statusLabel, $dateStr)',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedPlantingId = val),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _selectedPlantingId == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlantingSummaryScreen(
                          plantingId: _selectedPlantingId!,
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Lihat Ringkasan Siklus'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Hasil Panen (kg), kosongkan untuk memakai panen tercatat',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _harvestController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              ThousandsSeparatorInputFormatter(),
            ],
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isCalculating ? null : _calculateHpp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
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
                        color: AppColors.textMuted,
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
                            color: AppColors.primary,
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
