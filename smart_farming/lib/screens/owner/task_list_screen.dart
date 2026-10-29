import 'package:flutter/material.dart';

import '../../services/task_service.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  bool _isLoading = true;
  List<dynamic>? _tasks;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  void _fetchTasks() async {
    final data = await TaskService().getTasks();
    setState(() {
      _tasks = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daftar Tugas',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks == null || _tasks!.isEmpty
          ? const Center(child: Text('Belum ada tugas.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks!.length,
              itemBuilder: (context, index) {
                final task = _tasks![index];

                Color statusColor = Colors.grey;
                if (task['status'] == 'menunggu') statusColor = Colors.orange;
                if (task['status'] == 'dikerjakan') statusColor = Colors.blue;
                if (task['status'] == 'selesai') statusColor = Colors.green;
                if (task['status'] == 'batal') statusColor = Colors.red;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TaskDetailScreen(taskId: task['id']),
                      ),
                    ).then((_) => _fetchTasks());
                  },
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  task['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  task['status'].toString().toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lahan: ${task['planting']['land']['name']}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          Text(
                            'Buruh: ${task['assignee']?['name'] ?? 'Belum ada'}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const Divider(),
                          Text(
                            'Deadline: ${task['due_date'].toString().substring(0, 10)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
