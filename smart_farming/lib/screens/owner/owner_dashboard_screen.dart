import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/dashboard_service.dart';
import '../../services/land_service.dart';
import '../../services/review_queue_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/role_shell.dart';
import '../attendance/attendance_review_screen.dart';
import '../more/more_screen.dart';
import '../payroll/payroll_list_screen.dart';
import '../reports/report_review_screen.dart';
import 'add_task_screen.dart';
import 'analytics_screen.dart';
import 'failure_log_screen.dart';
import 'finance_screen.dart';
import 'incident_list_screen.dart';
import 'inventory_screen.dart';
import 'land_list_screen.dart';
import 'task_list_screen.dart';
import 'worker_list_screen.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        ShellTab(
          label: 'Beranda',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          builder: (context, goToTab) => _OwnerHome(goToTab: goToTab),
        ),
        ShellTab(
          label: 'Tugas',
          icon: Icons.task_alt_outlined,
          selectedIcon: Icons.task_alt_rounded,
          builder: (context, goToTab) => const TaskListScreen(),
        ),
        ShellTab(
          label: 'Lahan',
          icon: Icons.landscape_outlined,
          selectedIcon: Icons.landscape_rounded,
          builder: (context, goToTab) => const LandListScreen(),
        ),
        ShellTab(
          label: 'Keuangan',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          builder: (context, goToTab) => const FinanceScreen(),
        ),
        ShellTab(
          label: 'Lainnya',
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view_rounded,
          refreshOnOpen: false,
          builder: (context, goToTab) => MoreScreen(
            groups: [
              MoreGroupData(
                title: 'Tim & Upah',
                items: [
                  MoreItem(
                    label: 'Manajemen Karyawan',
                    subtitle: 'Mandor, buruh, jadwal, dan upah',
                    icon: Icons.people_alt_rounded,
                    builder: () => const WorkerListScreen(),
                  ),
                  MoreItem(
                    label: 'Verifikasi Absensi',
                    subtitle: 'Absensi mandor dan pengecualian',
                    icon: Icons.fact_check_rounded,
                    color: AppColors.accent,
                    builder: () => const AttendanceReviewScreen(),
                  ),
                  MoreItem(
                    label: 'Verifikasi Laporan',
                    subtitle: 'Laporan kerja yang naik ke pemilik',
                    icon: Icons.assignment_turned_in_rounded,
                    color: AppColors.water,
                    builder: () => const ReportReviewScreen(),
                  ),
                  MoreItem(
                    label: 'Rekap Upah',
                    subtitle: 'Hitung, setujui, dan bayar upah',
                    icon: Icons.payments_rounded,
                    color: AppColors.primaryDark,
                    builder: () => const PayrollListScreen(),
                  ),
                ],
              ),
              MoreGroupData(
                title: 'Lapangan & Stok',
                items: [
                  MoreItem(
                    label: 'Inventaris',
                    subtitle: 'Alat, bahan, pembelian, dan kerusakan',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.soil,
                    builder: () => const InventoryScreen(),
                  ),
                  MoreItem(
                    label: 'Laporan Insiden',
                    subtitle: 'Kejadian yang dilaporkan di lahan',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    builder: () => const IncidentListScreen(),
                  ),
                  MoreItem(
                    label: 'Risiko Gagal Panen',
                    subtitle: 'Cuaca dan laporan lapangan',
                    icon: Icons.crisis_alert_rounded,
                    color: AppColors.warning,
                    builder: () => const FailureLogScreen(),
                  ),
                ],
              ),
              MoreGroupData(
                title: 'Analisis',
                items: [
                  MoreItem(
                    label: 'Analitik Laba & Risiko',
                    subtitle: 'Laba per siklus dan skor risiko',
                    icon: Icons.insights_rounded,
                    color: AppColors.water,
                    builder: () => const AnalyticsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnerHome extends StatefulWidget {
  const _OwnerHome({required this.goToTab});

  final ValueChanged<int> goToTab;

  @override
  State<_OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<_OwnerHome> {
  String _userName = 'Pemilik';
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _weatherData;
  Map<String, int> _queue = {'attendance': 0, 'reports': 0};
  List<dynamic> _lands = [];
  int? _selectedLandId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _refreshAll();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _userName = prefs.getString('name') ?? 'Pemilik');
  }

  Future<void> _fetchStats() async {
    final data = await DashboardService().getOwnerStats();
    if (!mounted) return;
    setState(() {
      _stats = data;
      _isLoading = false;
    });
  }

  Future<void> _fetchQueue() async {
    final counts = await ReviewQueueService().counts();
    if (!mounted) return;
    setState(() => _queue = counts);
  }

  Future<void> _fetchLands() async {
    final lands = await LandService().getLands();
    if (!mounted) return;
    setState(() {
      _lands = lands ?? [];
      if (_lands.isNotEmpty && _selectedLandId == null) {
        _selectedLandId = _lands[0]['id'];
      }
    });
    await _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final data = await DashboardService().getWeather(landId: _selectedLandId);
    if (!mounted) return;
    setState(() => _weatherData = data);
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchStats(), _fetchQueue(), _fetchLands()]);
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      if (mounted) _refreshAll();
    });
  }

  String _money(dynamic value) {
    final n = (num.tryParse(value.toString()) ?? 0).round();
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp ${n < 0 ? '-' : ''}$buf';
  }

  Widget _weatherCard() {
    final w = _weatherData!;
    final condition = w['condition'];
    final IconData icon = condition == 'Rain'
        ? Icons.umbrella_rounded
        : condition == 'Clouds'
        ? Icons.cloud_rounded
        : Icons.wb_sunny_rounded;
    final Color iconColor = condition == 'Rain'
        ? AppColors.water
        : condition == 'Clouds'
        ? AppColors.soil
        : AppColors.accent;
    final temp = (num.tryParse(w['temperature'].toString()) ?? 0)
        .toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_lands.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedLandId,
                    isExpanded: true,
                    isDense: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      color: AppColors.textDark,
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
                              color: AppColors.primary,
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
                      if (val == null) return;
                      setState(() => _selectedLandId = val);
                      _fetchWeather();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$temp °C',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        w['description'].toString().toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
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
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Kelembapan ${w['humidity']}%',
                            style: const TextStyle(
                              color: AppColors.textMuted,
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
                  child: Icon(icon, size: 42, color: iconColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    final stats = _stats!;

    return Column(
      children: [
        HeroStatCard(label: 'Laba Bersih', value: _money(stats['net_profit'])),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Pemasukan',
                value: _money(stats['total_income']),
                icon: Icons.arrow_downward_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'Pengeluaran',
                value: _money(stats['total_expense']),
                icon: Icons.arrow_upward_rounded,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Lahan Aktif',
                value: '${stats['total_lands']}',
                icon: Icons.landscape_rounded,
                color: AppColors.soil,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'Tugas Aktif',
                value: '${stats['active_tasks']}',
                icon: Icons.assignment_turned_in_rounded,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _content() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader(
              name: _userName,
              roleLabel: 'Pemilik',
              onAvatarTap: () => widget.goToTab(4),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xl,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Ringkasan'),
                  _summary(),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle('Perlu Tindakan'),
                  ActionGrid(children: [
                    ActionTile(
                      label: 'Verifikasi Absensi',
                      icon: Icons.fact_check_rounded,
                      color: AppColors.accent,
                      badge: _queue['attendance'] ?? 0,
                      onTap: () => _open(const AttendanceReviewScreen()),
                    ),
                    ActionTile(
                      label: 'Verifikasi Laporan',
                      icon: Icons.assignment_turned_in_rounded,
                      color: AppColors.water,
                      badge: _queue['reports'] ?? 0,
                      onTap: () => _open(const ReportReviewScreen()),
                    ),
                    ActionTile(
                      label: 'Rekap Upah',
                      icon: Icons.payments_rounded,
                      color: AppColors.primaryDark,
                      onTap: () => _open(const PayrollListScreen()),
                    ),
                  ]),
                  if (_weatherData != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle('Cuaca Lahan'),
                    _weatherCard(),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle('Akses Cepat'),
                  ActionGrid(children: [
                    ActionTile(
                      label: 'Buat Tugas',
                      icon: Icons.add_task_rounded,
                      onTap: () => _open(const AddTaskScreen()),
                    ),
                    ActionTile(
                      label: 'Karyawan',
                      icon: Icons.people_alt_rounded,
                      onTap: () => _open(const WorkerListScreen()),
                    ),
                    ActionTile(
                      label: 'Analitik',
                      icon: Icons.insights_rounded,
                      color: AppColors.water,
                      onTap: () => _open(const AnalyticsScreen()),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
          ? ErrorState(
              message: 'Gagal memuat data beranda.',
              onRetry: () {
                setState(() => _isLoading = true);
                _refreshAll();
              },
            )
          : _content(),
    );
  }
}
