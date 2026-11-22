import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/dashboard_service.dart';
import '../../services/review_queue_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/role_shell.dart';
import '../attendance/attendance_review_screen.dart';
import '../attendance/my_attendance_screen.dart';
import '../more/more_screen.dart';
import '../owner/add_task_screen.dart';
import '../owner/failure_log_screen.dart';
import '../owner/incident_list_screen.dart';
import '../owner/inventory_screen.dart';
import '../owner/land_list_screen.dart';
import '../owner/task_list_screen.dart';
import '../owner/worker_list_screen.dart';
import '../payroll/my_payslip_screen.dart';
import '../reports/report_review_screen.dart';

class MandorDashboardScreen extends StatelessWidget {
  const MandorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        ShellTab(
          label: 'Beranda',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          builder: (context, goToTab) => _MandorHome(goToTab: goToTab),
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
          label: 'Inventaris',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          builder: (context, goToTab) => const InventoryScreen(),
        ),
        ShellTab(
          label: 'Lainnya',
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view_rounded,
          refreshOnOpen: false,
          builder: (context, goToTab) => MoreScreen(
            groups: [
              MoreGroupData(
                title: 'Kerja Saya',
                items: [
                  MoreItem(
                    label: 'Absensi Saya',
                    subtitle: 'Absen masuk dan pulang',
                    icon: Icons.fingerprint,
                    builder: () => const MyAttendanceScreen(),
                  ),
                  MoreItem(
                    label: 'Slip Upah Saya',
                    subtitle: 'Riwayat upah dan potongan',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primaryDark,
                    builder: () => const MyPayslipScreen(),
                  ),
                ],
              ),
              MoreGroupData(
                title: 'Tim',
                items: [
                  MoreItem(
                    label: 'Verifikasi Absensi',
                    subtitle: 'Absensi buruh',
                    icon: Icons.fact_check_rounded,
                    color: AppColors.accent,
                    builder: () => const AttendanceReviewScreen(),
                  ),
                  MoreItem(
                    label: 'Verifikasi Laporan',
                    subtitle: 'Laporan kerja buruh',
                    icon: Icons.assignment_turned_in_rounded,
                    color: AppColors.water,
                    builder: () => const ReportReviewScreen(),
                  ),
                  MoreItem(
                    label: 'Kelola Buruh',
                    subtitle: 'Data buruh dan jadwal kerja',
                    icon: Icons.people_alt_rounded,
                    builder: () => const WorkerListScreen(),
                  ),
                ],
              ),
              MoreGroupData(
                title: 'Lapangan',
                items: [
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
            ],
          ),
        ),
      ],
    );
  }
}

class _MandorHome extends StatefulWidget {
  const _MandorHome({required this.goToTab});

  final ValueChanged<int> goToTab;

  @override
  State<_MandorHome> createState() => _MandorHomeState();
}

class _MandorHomeState extends State<_MandorHome> {
  String _userName = 'Mandor';
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  Map<String, int> _queue = {'attendance': 0, 'reports': 0};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _refreshAll();
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

  Future<void> _fetchQueue() async {
    final counts = await ReviewQueueService().counts();
    if (!mounted) return;
    setState(() => _queue = counts);
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchStats(), _fetchQueue()]);
  }

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      if (mounted) _refreshAll();
    });
  }

  Widget _content() {
    final stats = _stats;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader(
              name: _userName,
              roleLabel: 'Mandor Lapangan',
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
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Lahan',
                          value: '${stats?['total_lands'] ?? 0}',
                          icon: Icons.landscape_rounded,
                          color: AppColors.soil,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatCard(
                          label: 'Tugas Aktif',
                          value: '${stats?['active_tasks'] ?? 0}',
                          icon: Icons.assignment_turned_in_rounded,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatCard(
                          label: 'Buruh Aktif',
                          value: '${stats?['active_workers'] ?? 0}',
                          icon: Icons.people_alt_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle('Perlu Diverifikasi'),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 118,
                          child: ActionTile(
                            label: 'Verifikasi Absensi',
                            icon: Icons.fact_check_rounded,
                            color: AppColors.accent,
                            badge: _queue['attendance'] ?? 0,
                            onTap: () => _open(const AttendanceReviewScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SizedBox(
                          height: 118,
                          child: ActionTile(
                            label: 'Verifikasi Laporan',
                            icon: Icons.assignment_turned_in_rounded,
                            color: AppColors.water,
                            badge: _queue['reports'] ?? 0,
                            onTap: () => _open(const ReportReviewScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle('Akses Cepat'),
                  ActionGrid(children: [
                    ActionTile(
                      label: 'Absensi Saya',
                      icon: Icons.fingerprint,
                      onTap: () => _open(const MyAttendanceScreen()),
                    ),
                    ActionTile(
                      label: 'Buat Tugas',
                      icon: Icons.add_task_rounded,
                      onTap: () => _open(const AddTaskScreen()),
                    ),
                    ActionTile(
                      label: 'Slip Upah',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.primaryDark,
                      onTap: () => _open(const MyPayslipScreen()),
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
          : _content(),
    );
  }
}
