import 'package:flutter/material.dart';

import '../../services/tool_service.dart';
import '../../services/resource_service.dart';
import 'add_tool_screen.dart';
import 'add_resource_screen.dart';

import 'package:flutter/services.dart';

import '../../utils/currency_formatter.dart';

import 'package:intl/intl.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
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
        title: const Text('Inventaris', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Alat', icon: Icon(Icons.handyman)),
            Tab(text: 'Bahan', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_ToolTab(), _ResourceTab()],
      ),
    );
  }
}

class _ToolTab extends StatefulWidget {
  @override
  State<_ToolTab> createState() => _ToolTabState();
}

class _ToolTabState extends State<_ToolTab> {
  bool _isLoading = true;
  List<dynamic>? _tools;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    final data = await ToolService().getTools();
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
            const SizedBox(height: 8),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Satuan'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Alat',
                helperText: 'Mengurangi/menambah unit otomatis',
              ),
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
              if (success) {
                _fetch();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Gagal menghapus. Alat mungkin sedang dipinjam.',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tools == null || _tools!.isEmpty
          ? const Center(child: Text('Belum ada alat.'))
          : ListView.builder(
              itemCount: _tools!.length,
              itemBuilder: (context, index) {
                final tool = _tools![index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.build, color: Color(0xFF2E7D32)),
                    title: Text(
                      tool['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Tersedia: ${tool['available_qty']} / ${tool['total_qty']} ${tool['unit_label'] ?? ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                            size: 20,
                          ),
                          onPressed: () => _showEditDialog(tool),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
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
        backgroundColor: const Color(0xFF2E7D32),
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
  @override
  State<_ResourceTab> createState() => _ResourceTabState();
}

class _ResourceTabState extends State<_ResourceTab> {
  bool _isLoading = true;
  List<dynamic>? _resources;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    final data = await ResourceService().getResources();
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
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Satuan'),
              ),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok'),
              ),
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

              final success = await ResourceService().updateResource(
                res['id'],
                {
                  'name': nameController.text,
                  'unit': unitController.text,
                  'stock_qty': double.tryParse(stockController.text) ?? 0,
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
              backgroundColor: const Color(0xFF2E7D32),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resources == null || _resources!.isEmpty
          ? const Center(child: Text('Belum ada bahan.'))
          : ListView.builder(
              itemCount: _resources!.length,
              itemBuilder: (context, index) {
                final res = _resources![index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.science, color: Colors.blue),
                    title: Text(
                      res['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Stok: ${res['stock_qty']} ${res['unit']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          ).format(double.parse(res['unit_price'].toString())),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                            size: 20,
                          ),
                          onPressed: () => _showEditDialog(res),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _showDeleteDialog(res),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fabResource',
        backgroundColor: Colors.blue,
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
