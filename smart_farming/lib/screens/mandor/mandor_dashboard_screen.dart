import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/dashboard_service.dart';
import '../attendance/attendance_review_screen.dart';
import '../attendance/my_attendance_screen.dart';
import '../reports/report_review_screen.dart';
import '../owner/add_task_screen.dart';
import '../owner/failure_log_screen.dart';
import '../owner/incident_list_screen.dart';
import '../owner/inventory_screen.dart';
import '../owner/task_list_screen.dart';
import '../owner/worker_list_screen.dart';
import '../profile/profile_screen.dart';

class MandorDashboardScreen extends StatefulWidget {
  const MandorDashboardScreen({super.key});

  @override
  State<MandorDashboardScreen> createState() => _MandorDashboardScreenState();
}

class _MandorDashboardScreenState extends State<MandorDashboardScreen> {
  String _userName = 'Mandor';
  bool _isLoading = true;
  int _currentIndex = 0;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchStats();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _userName = prefs.getString('name') ?? 'Mandor');
  }

  Future<void> _fetchStats() async {
    final data = await DashboardService().getMandorStats();
    if (!mounted) return;
    setState(() {
      _stats = data;
      _isLoading = false;
    });
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _fetchStats());
  }

  Widget _statCard(String label, dynamic value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                '${value ?? 0}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(String label, IconData icon, Widget screen) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(screen),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Halo, $_userName',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('Mandor lapangan'),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                _statCard('Lahan', _stats?['total_lands'], Icons.landscape_rounded),
                const SizedBox(width: 8),
                _statCard(
                  'Tugas Aktif',
                  _stats?['active_tasks'],
                  Icons.assignment_turned_in_rounded,
                ),
                const SizedBox(width: 8),
                _statCard(
                  'Buruh Aktif',
                  _stats?['active_workers'],
                  Icons.people_alt_rounded,
                ),
              ],
            ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _menuTile(
                'Absensi Saya',
                Icons.fingerprint,
                const MyAttendanceScreen(),
              ),
              _menuTile(
                'Verifikasi Absensi',
                Icons.fact_check_rounded,
                const AttendanceReviewScreen(),
              ),
              _menuTile(
                'Verifikasi Laporan',
                Icons.assignment_turned_in_rounded,
                const ReportReviewScreen(),
              ),
              _menuTile('Buat Tugas', Icons.add_task_rounded, const AddTaskScreen()),
              _menuTile('Inventaris', Icons.inventory_2_rounded, const InventoryScreen()),
              _menuTile('Kelola Buruh', Icons.people_alt_rounded, const WorkerListScreen()),
              _menuTile(
                'Laporan Insiden',
                Icons.warning_amber_rounded,
                const IncidentListScreen(),
              ),
              _menuTile(
                'Risiko Gagal Panen',
                Icons.crisis_alert_rounded,
                const FailureLogScreen(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHome(),
      const TaskListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: _currentIndex == 0 ? AppBar(title: const Text('Tani Pintar')) : null,
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.task_alt_rounded), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}
