import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/worker_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/role_shell.dart';
import '../attendance/my_attendance_screen.dart';
import '../owner/task_list_screen.dart';
import '../payroll/my_payslip_screen.dart';
import '../profile/profile_screen.dart';
import 'add_incident_screen.dart';

class WorkerDashboardScreen extends StatelessWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      tabs: [
        ShellTab(
          label: 'Beranda',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          builder: (context, goToTab) => _WorkerHome(goToTab: goToTab),
        ),
        ShellTab(
          label: 'Tugas',
          icon: Icons.task_alt_outlined,
          selectedIcon: Icons.task_alt_rounded,
          builder: (context, goToTab) => const TaskListScreen(),
        ),
        ShellTab(
          label: 'Absensi',
          icon: Icons.fingerprint,
          selectedIcon: Icons.fingerprint,
          builder: (context, goToTab) => const MyAttendanceScreen(),
        ),
        ShellTab(
          label: 'Upah',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long_rounded,
          builder: (context, goToTab) => const MyPayslipScreen(),
        ),
        ShellTab(
          label: 'Profil',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          refreshOnOpen: false,
          builder: (context, goToTab) => const ProfileScreen(),
        ),
      ],
    );
  }
}

class _WorkerHome extends StatefulWidget {
  const _WorkerHome({required this.goToTab});

  final ValueChanged<int> goToTab;

  @override
  State<_WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<_WorkerHome> {
  String _userName = 'Buruh';
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = await WorkerService().getWorkerStats();
    if (!mounted) return;

    setState(() {
      _userName = prefs.getString('name') ?? 'Buruh';
      _stats = data;
      _isLoading = false;
    });
  }

  Widget _content() {
    final stats = _stats!;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader(
              name: _userName,
              roleLabel: 'Buruh',
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
                          label: 'Tugas Hari Ini',
                          value: '${stats['todays_tasks_count']}',
                          icon: Icons.today_rounded,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: StatCard(
                          label: 'Selesai Bulan Ini',
                          value: '${stats['completed_this_month']}',
                          icon: Icons.task_alt_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionTitle('Aksi Cepat'),
                  ActionGrid(
                    children: [
                      ActionTile(
                        label: 'Absensi Hari Ini',
                        icon: Icons.fingerprint,
                        onTap: () => widget.goToTab(2),
                      ),
                      ActionTile(
                        label: 'Tugas Saya',
                        icon: Icons.task_alt_rounded,
                        color: AppColors.accent,
                        onTap: () => widget.goToTab(1),
                      ),
                      ActionTile(
                        label: 'Lapor Insiden',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddIncidentScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                _loadData();
              },
            )
          : _content(),
    );
  }
}
