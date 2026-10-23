import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/dashboard_service.dart';
import 'land_list_screen.dart';
import 'task_list_screen.dart';
import '../profile/profile_screen.dart';
import 'worker_list_screen.dart';
import 'inventory_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  String _userName = 'Pemilik';
  bool _isLoading = true;
  int _currentIndex = 0;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchStats();
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('name') ?? 'Pemilik';
    });
  }

  void _fetchStats() async {
    final data = await DashboardService().getOwnerStats();
    setState(() {
      _stats = data;
      _isLoading = false;
    });
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border(top: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Dashboard Pemilik',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
          ? const Center(child: Text('Gagal memuat data dashboard.'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang,',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkerListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people, color: Colors.white),
                    label: const Text(
                      'Manajemen Buruh',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),

                  ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()));
                        },
                        icon: const Icon(Icons.inventory_2, color: Colors.white),
                        label: const Text('Manajemen Inventaris', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                  const SizedBox(height: 24),

                  // Grid Statistik
                  Row(
                    children: [
                      _buildStatCard(
                        'Pemasukan',
                        'Rp ${_stats!['total_income']}',
                        Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Pengeluaran',
                        'Rp ${_stats!['total_expense']}',
                        Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(
                        'Laba Bersih',
                        'Rp ${_stats!['net_profit']}',
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Lahan Aktif',
                        '${_stats!['total_lands']}',
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(
                        'Tugas Aktif',
                        '${_stats!['active_tasks']}',
                        Colors.purple,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Daftar halaman yang akan ditampilkan sesuai tab
    final List<Widget> pages = [
      _buildHomeTab(), // Tab 0: Dashboard
      const LandListScreen(), // Tab 1: Lahan
      const TaskListScreen(), // Tab 2: Tugas
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.landscape), label: 'Lahan'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tugas'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
