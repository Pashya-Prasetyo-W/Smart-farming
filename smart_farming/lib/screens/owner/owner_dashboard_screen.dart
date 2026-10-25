import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/dashboard_service.dart';
import 'land_list_screen.dart';
import 'task_list_screen.dart';
import '../profile/profile_screen.dart';
import 'worker_list_screen.dart';
import 'inventory_screen.dart';
import 'add_task_screen.dart';
import 'incident_list_screen.dart';
import 'finance_screen.dart';
import 'failure_log_screen.dart';
import '../../services/land_service.dart';

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
  Map<String, dynamic>? _weatherData;
  List<dynamic> _lands = [];
  int? _selectedLandIdForWeather;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchStats();
    _fetchWeather();
    _fetchLandsForWeather();
  }

  void _fetchLandsForWeather() async {
    final lands = await LandService().getLands();
    if (mounted) {
      setState(() {
        _lands = lands ?? [];
        if (_lands.isNotEmpty) {
          _selectedLandIdForWeather = _lands[0]['id'];
          _fetchWeather(); // Ambil cuaca untuk lahan pertama
        }
      });
    }
  }

  void _fetchWeather() async {
    final data = await DashboardService().getWeather(
      landId: _selectedLandIdForWeather,
    );
    if (mounted) {
      setState(() {
        _weatherData = data;
      });
    }
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
          : SingleChildScrollView(
              child: Padding(
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
                    const SizedBox(height: 16),

                    // --- CARD CUACA ---
                    if (_weatherData != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0288D1), Color(0xFF4FC3F7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        // UBAH MENJADI COLUMN
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Dropdown Pilih Lahan
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedLandIdForWeather,
                                  isExpanded:
                                      true, // Agar mengambil seluruh lebar
                                  isDense: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                  ),
                                  dropdownColor: const Color(0xFF0288D1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  items: _lands.map((land) {
                                    return DropdownMenuItem<int>(
                                      value: land['id'],
                                      child: Text(
                                        'Cuaca di ${land['name']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedLandIdForWeather = val;
                                      });
                                      _fetchWeather();
                                    }
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 2. Suhu dan Icon
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_weatherData!['temperature'].toStringAsFixed(1)} °C',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${_weatherData!['description'].toString().toUpperCase()} • Kelembapan ${_weatherData!['humidity']}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  _weatherData!['condition'] == 'Rain'
                                      ? Icons.umbrella
                                      : _weatherData!['condition'] == 'Clouds'
                                      ? Icons.cloud
                                      : Icons.wb_sunny,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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

                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const InventoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.inventory_2, color: Colors.white),
                      label: const Text(
                        'Manajemen Inventaris',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddTaskScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.assignment_add,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Buat Tugas Baru',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),

                    const SizedBox(height: 16),
                    // --- TOMBOL LAPORAN INSIDEN ---
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IncidentListScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Lihat Laporan Insiden',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // --- TOMBOL KEUANGAN ---
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FinanceScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Keuangan & Kalkulasi HPP',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FailureLogScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.warning, color: Colors.white),
                      label: const Text(
                        'Cek Risiko Gagal Panen',
                        style: TextStyle(color: Colors.white),
                      ),
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
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Daftar halaman yang akan ditampilkan sesuai tab
    final List<Widget> pages = [
      _buildHomeTab(), // Tab 0: Dashboard
      const LandListScreen(),
      const TaskListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
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
