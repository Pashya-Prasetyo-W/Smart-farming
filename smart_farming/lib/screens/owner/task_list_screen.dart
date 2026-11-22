import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/task_service.dart';
import '../../utils/rupiah.dart';
import 'task_detail_screen.dart';
import '../../utils/search.dart';
import '../../utils/task_status.dart';
import '../../widgets/search_field.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import 'add_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  bool _isLoading = true;
  bool _canCreate = false;
  List<dynamic>? _tasks;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
    _fetchTasks();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (!mounted) return;
    setState(() => _canCreate = role == 'pemilik' || role == 'mandor');
  }

  void _fetchTasks() async {
    final data = await TaskService().getTasks();
    if (!mounted) return;
    setState(() {
      _tasks = data;
      _isLoading = false;
    });
  }

  List<dynamic> get _filteredTasks {
    return (_tasks ?? []).where((task) {
      return matchesSearch(_query, [
        task['title'],
        task['description'],
        task['status'],
        task['assignee']?['name'],
        task['planting']?['crop_name'],
        task['planting']?['land']?['name'],
      ]);
    }).toList();
  }

  Future<void> _openDetail(dynamic task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(taskId: task['id']),
      ),
    );
    _fetchTasks();
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTaskScreen()),
    );
    _fetchTasks();
  }

  Widget _taskCard(dynamic task) {
    final statusColor = taskStatusColor(task['status']);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: () => _openDetail(task),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task['title'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: taskStatusLabel(task['status']),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InfoLine(
                icon: Icons.landscape_rounded,
                text: '${task['planting']['land']['name']}',
              ),
              InfoLine(
                icon: Icons.person_rounded,
                text: '${task['assignee']?['name'] ?? 'Belum ada pelaksana'}',
              ),
              if (task['wage_amount'] != null)
                InfoLine(
                  icon: Icons.payments_rounded,
                  text: 'Upah tugas ${Rupiah.format(task['wage_amount'])}',
                ),
              InfoLine(
                icon: Icons.event_rounded,
                text:
                    'Tenggat ${task['due_date'].toString().substring(0, 10)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Tugas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SearchField(
            hint: 'Cari tugas, pelaksana, lahan, status...',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Buat Tugas'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks == null || _tasks!.isEmpty
          ? const EmptyState(
              message: 'Belum ada tugas.',
              icon: Icons.task_alt_rounded,
            )
          : tasks.isEmpty
          ? EmptyState(
              message: 'Tidak ada hasil untuk "$_query".',
              icon: Icons.search_off_rounded,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.page,
                AppSpacing.page,
                88,
              ),
              itemCount: tasks.length,
              itemBuilder: (context, index) => _taskCard(tasks[index]),
            ),
    );
  }
}
