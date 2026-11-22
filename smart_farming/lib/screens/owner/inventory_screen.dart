import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/tool_service.dart';
import '../../services/resource_service.dart';
import 'add_tool_screen.dart';
import 'add_resource_screen.dart';
import 'inventory_incident_tab.dart';
import 'inventory_purchase_tab.dart';

import 'package:flutter/services.dart';

import '../../utils/currency_formatter.dart';

import 'package:intl/intl.dart';
import '../../utils/search.dart';
import '../../widgets/search_field.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOwner = false;
  int? _userId;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isOwner = prefs.getString('role') == 'pemilik';
      _userId = prefs.getInt('user_id');
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaris'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Alat', icon: Icon(Icons.handyman)),
            Tab(text: 'Bahan', icon: Icon(Icons.science)),
            Tab(text: 'Pembelian', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Kerusakan', icon: Icon(Icons.report_problem)),
          ],
        ),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ToolTab(isOwner: _isOwner),
                _ResourceTab(isOwner: _isOwner),
                PurchaseTab(isOwner: _isOwner, userId: _userId),
                IncidentTab(isOwner: _isOwner),
              ],
            ),
    );
  }
}

class _ToolTab extends StatefulWidget {
  const _ToolTab({required this.isOwner});

  final bool isOwner;

  @override
  State<_ToolTab> createState() => _ToolTabState();
}

class _ToolTabState extends State<_ToolTab> {
  bool _isLoading = true;
  List<dynamic>? _tools;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    final data = await ToolService().getTools();
    if (!mounted) return;
    setState(() {
      _tools = data;
      _isLoading = false;
    });
  }

  void _showEditDialog(dynamic tool) {
    final nameController = TextEditingController(text: tool['name']);
    final labelController = TextEditingController(text: tool['unit_label']);
    final qtyController = TextEditingController(
      text: tool['total_qty'].toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Alat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Alat'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Satuan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Alat'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final success = await ToolService().updateTool(tool['id'], {
                'name': nameController.text,
                'unit_label': labelController.text,
                'total_qty':
                    int.tryParse(qtyController.text) ?? tool['total_qty'],
              });

              if (success && context.mounted) {
                _fetch();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alat berhasil diupdate!')),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Gagal update. Cek terminal Laravel/Flutter.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(dynamic tool) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Alat'),
        content: Text('Hapus alat ${tool['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ToolService().deleteTool(tool['id']);
              
              if (!mounted) return;

              if (success) {
                _fetch();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alat berhasil dihapus!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal menghapus. Alat mungkin sedang dipinjam.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<dynamic> get _filteredTools {
    return (_tools ?? []).where((tool) {
      return matchesSearch(_query, [
        tool['name'],
        tool['unit_label'],
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tools = _filteredTools;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: SearchField(
          hint: 'Cari alat...',
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tools == null || _tools!.isEmpty
          ? const EmptyState(message: 'Belum ada alat.')
          : tools.isEmpty
          ? EmptyState(message: 'Tidak ada hasil untuk "$_query".', icon: Icons.search_off_rounded)
          : ListView.builder(
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.build, color: AppColors.primary),
                    title: Text(
                      tool['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Tersedia: ${tool['available_qty']} / ${tool['total_qty']} ${tool['unit_label'] ?? ''}'
                      '${(tool['damaged_units_count'] ?? 0) > 0 ? '\nRusak: ${tool['damaged_units_count']}' : ''}'
                      '${(tool['lost_units_count'] ?? 0) > 0 ? '\nHilang: ${tool['lost_units_count']}' : ''}',
                    ),
                    isThreeLine: (tool['damaged_units_count'] ?? 0) > 0 ||
                        (tool['lost_units_count'] ?? 0) > 0,
                    trailing: !widget.isOwner
                        ? null
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: AppColors.water,
                            size: 20,
                          ),
                          onPressed: () => _showEditDialog(tool),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          onPressed: () => _showDeleteDialog(tool),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fabTool',
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddToolScreen()),
          );
          _fetch();
        },
      ),
    );
  }
}

class _ResourceTab extends StatefulWidget {
  const _ResourceTab({required this.isOwner});

  final bool isOwner;

  @override
  State<_ResourceTab> createState() => _ResourceTabState();
}

class _ResourceTabState extends State<_ResourceTab> {
  bool _isLoading = true;
  List<dynamic>? _resources;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    final data = await ResourceService().getResources();
    if (!mounted) return;
    setState(() {
      _resources = data;
      _isLoading = false;
    });
  }

  void _showEditDialog(dynamic res) {
    final nameController = TextEditingController(text: res['name']);
    final unitController = TextEditingController(text: res['unit']);
    final stockController = TextEditingController(
      text: res['stock_qty'].toString(),
    );
    final priceController = TextEditingController(
      text: res['unit_price'].toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Bahan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama Bahan'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Satuan'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: const InputDecoration(labelText: 'Harga'),
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
              Navigator.pop(dialogContext);

              final cleanPriceStr = priceController.text.replaceAll('.', '');
              final cleanStock = stockController.text.replaceAll('.', '');

              final success = await ResourceService().updateResource(
                res['id'],
                {
                  'name': nameController.text,
                  'unit': unitController.text,
                  'stock_qty': double.tryParse(cleanStock) ?? 0,
                  'unit_price': double.tryParse(cleanPriceStr) ?? 0,
                },
              );

              if (success && context.mounted) {
                _fetch();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bahan berhasil diedit!')),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal edit. Cek terminal.')),
                );
              }
            },

            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(dynamic res) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Bahan'),
        content: Text('Hapus bahan ${res['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ResourceService().deleteResource(res['id']);

              if (success && context.mounted) {
                _fetch();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bahan berhasil dihapus!')),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal hapus. Cek terminal.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _qty(dynamic value) {
    final number = num.tryParse(value?.toString() ?? '');
    if (number == null) return value?.toString() ?? '-';
    if (number == number.roundToDouble()) return number.toInt().toString();
    return number.toStringAsFixed(2);
  }

  Future<void> _buy(dynamic res) async {
    final message = await showPurchaseDialog(
      context,
      resources: _resources ?? [],
      preselected: Map<String, dynamic>.from(res as Map),
    );
    if (message == null || !mounted) return;
    _fetch();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<dynamic> get _filteredResources {
    return (_resources ?? []).where((res) {
      return matchesSearch(_query, [
        res['name'],
        res['unit'],
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final resources = _filteredResources;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: SearchField(
          hint: 'Cari bahan...',
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resources == null || _resources!.isEmpty
          ? const EmptyState(message: 'Belum ada bahan.')
          : resources.isEmpty
          ? EmptyState(message: 'Tidak ada hasil untuk "$_query".', icon: Icons.search_off_rounded)
          : ListView.builder(
              itemCount: resources.length,
              itemBuilder: (context, index) {
                final res = resources[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.science, color: AppColors.water),
                        title: Text(
                          res['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Stok: ${_qty(res['stock_qty'])} ${res['unit']}\n'
                          'Dipesan tugas: ${_qty(res['reserved_qty'])} ${res['unit']}\n'
                          'Tersedia: ${_qty(res['available_qty'])} ${res['unit']}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(double.parse(res['unit_price'].toString())),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _buy(res),
                              icon: const Icon(Icons.add_shopping_cart, size: 18),
                              label: const Text('Beli'),
                            ),
                            if (widget.isOwner) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: AppColors.water,
                                  size: 20,
                                ),
                                onPressed: () => _showEditDialog(res),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.danger,
                                  size: 20,
                                ),
                                onPressed: () => _showDeleteDialog(res),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fabResource',
        backgroundColor: AppColors.water,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddResourceScreen()),
          );
          _fetch();
        },
      ),
    );
  }
}
