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

class _Palette {
  static const primary = Color(0xFF2E7D32);
  static const primaryDark = Color(0xFF1B5E20);
  static const primaryLight = Color(0xFF66BB6A);
  static const accent = Color(0xFFF9A825);
  static const soil = Color(0xFF8D6E63);
  static const teal = Color(0xFF00796B);
  static const danger = Color(0xFFC62828);
  static const background = Color(0xFFF3F7F1);
  static const surface = Colors.white;
  static const textDark = Color(0xFF1E2B1F);
  static const textMuted = Color(0xFF6B7A6C);
}

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
    _fetchLandsForWeather();
  }

  Future<void> _fetchLandsForWeather() async {
    final lands = await LandService().getLands();
    if (!mounted) return;
    setState(() {
      _lands = lands ?? [];
      if (_lands.isNotEmpty) {
        _selectedLandIdForWeather = _lands[0]['id'];
      }
    });
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final data = await DashboardService().getWeather(
      landId: _selectedLandIdForWeather,
    );
    if (mounted) {
      setState(() {
        _weatherData = data;
      });
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('name') ?? 'Pemilik';
    });
  }

  Future<void> _fetchStats() async {
    final data = await DashboardService().getOwnerStats();
    if (!mounted) return;
    setState(() {
      _stats = data;
      _isLoading = false;
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchStats(), _fetchLandsForWeather()]);
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String _rupiah(dynamic value) {
    final n = (num.tryParse(value.toString()) ?? 0).round();
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp ${n < 0 ? '-' : ''}$buf';
  }

  Widget _buildHeader() {
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'P';
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_Palette.primaryDark, _Palette.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang,',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dashboard Pemilik',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 26,
                backgroundColor: _Palette.accent,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _Palette.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    final w = _weatherData!;
    final condition = w['condition'];
    final IconData icon = condition == 'Rain'
        ? Icons.umbrella_rounded
        : condition == 'Clouds'
        ? Icons.cloud_rounded
        : Icons.wb_sunny_rounded;
    final Color iconColor = condition == 'Rain'
        ? _Palette.teal
        : condition == 'Clouds'
        ? _Palette.soil
        : _Palette.accent;
    final temp = (num.tryParse(w['temperature'].toString()) ?? 0)
        .toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _Palette.primary.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_lands.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _Palette.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedLandIdForWeather,
                  isExpanded: true,
                  isDense: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _Palette.primary,
                  ),
                  dropdownColor: _Palette.surface,
                  style: const TextStyle(
                    color: _Palette.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  items: _lands.map((land) {
                    return DropdownMenuItem<int>(
                      value: land['id'],
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: _Palette.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Cuaca di ${land['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
          if (_lands.isNotEmpty) const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temp °C',
                      style: const TextStyle(
                        color: _Palette.textDark,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      w['description'].toString().toUpperCase(),
                      style: const TextStyle(
                        color: _Palette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.water_drop_rounded,
                          size: 14,
                          color: _Palette.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Kelembapan ${w['humidity']}%',
                          style: const TextStyle(
                            color: _Palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: iconColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfitCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_Palette.primary, _Palette.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _Palette.primary.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laba Bersih',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _rupiah(_stats!['net_profit']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Palette.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: _Palette.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _Palette.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      children: [
        _buildProfitCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              'Pemasukan',
              _rupiah(_stats!['total_income']),
              Icons.arrow_downward_rounded,
              _Palette.primary,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Pengeluaran',
              _rupiah(_stats!['total_expense']),
              Icons.arrow_upward_rounded,
              _Palette.danger,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              'Lahan Aktif',
              '${_stats!['total_lands']}',
              Icons.landscape_rounded,
              _Palette.soil,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              'Tugas Aktif',
              '${_stats!['active_tasks']}',
              Icons.assignment_turned_in_rounded,
              _Palette.accent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _Palette.textDark,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _Palette.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _Palette.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    final items = <Widget>[
      _buildMenuTile(
        label: 'Manajemen Buruh',
        icon: Icons.people_alt_rounded,
        color: _Palette.primary,
        onTap: () => _open(const WorkerListScreen()),
      ),
      _buildMenuTile(
        label: 'Manajemen Inventaris',
        icon: Icons.inventory_2_rounded,
        color: _Palette.soil,
        onTap: () => _open(const InventoryScreen()),
      ),
      _buildMenuTile(
        label: 'Buat Tugas Baru',
        icon: Icons.add_task_rounded,
        color: _Palette.teal,
        onTap: () => _open(const AddTaskScreen()),
      ),
      _buildMenuTile(
        label: 'Laporan Insiden',
        icon: Icons.warning_amber_rounded,
        color: _Palette.danger,
        onTap: () => _open(const IncidentListScreen()),
      ),
      _buildMenuTile(
        label: 'Keuangan & Kalkulasi HPP',
        icon: Icons.account_balance_wallet_rounded,
        color: _Palette.primaryDark,
        onTap: () => _open(const FinanceScreen()),
      ),
      _buildMenuTile(
        label: 'Cek Risiko Gagal Panen',
        icon: Icons.crisis_alert_rounded,
        color: const Color(0xFFEF6C00),
        onTap: () => _open(const FailureLogScreen()),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: items,
    );
  }

  Widget _buildHomeTab() {
    return Scaffold(
      backgroundColor: _Palette.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _Palette.primary),
            )
          : _stats == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: _Palette.textMuted,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gagal memuat data dashboard.',
                    style: TextStyle(color: _Palette.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _fetchStats();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Palette.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: _Palette.primary,
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_weatherData != null) ...[
                            _buildSectionTitle('Cuaca Lahan'),
                            _buildWeatherCard(),
                            const SizedBox(height: 24),
                          ],

                          _buildSectionTitle('Ringkasan'),
                          _buildStatsSection(),
                          const SizedBox(height: 24),

                          _buildSectionTitle('Menu Cepat'),
                          _buildMenuGrid(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeTab(),
      const LandListScreen(),
      const TaskListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: _Palette.surface,
          elevation: 0,
          selectedItemColor: _Palette.primary,
          unselectedItemColor: _Palette.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.landscape_rounded),
              label: 'Lahan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_rounded),
              label: 'Tugas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
