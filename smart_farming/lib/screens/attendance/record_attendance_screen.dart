import 'package:flutter/material.dart';

import '../../services/attendance_service.dart';
import '../../services/worker_service.dart';
import '../../utils/attendance_format.dart';
import '../../theme/app_theme.dart';

class RecordAttendanceScreen extends StatefulWidget {
  const RecordAttendanceScreen({super.key});

  @override
  State<RecordAttendanceScreen> createState() => _RecordAttendanceScreenState();
}

class _RecordAttendanceScreenState extends State<RecordAttendanceScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _workers = [];
  int? _userId;
  DateTime _date = DateTime.now();
  TimeOfDay _checkIn = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _checkOut = const TimeOfDay(hour: 16, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    final data = await WorkerService().getWorkers();
    if (!mounted) return;

    setState(() {
      _workers = (data ?? [])
          .cast<Map<String, dynamic>>()
          .where((worker) => worker['is_active'] != false)
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 31)),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCheckIn() async {
    final picked = await showTimePicker(context: context, initialTime: _checkIn);
    if (picked != null) setState(() => _checkIn = picked);
  }

  Future<void> _pickCheckOut() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkOut ?? const TimeOfDay(hour: 16, minute: 0),
    );
    if (picked != null) setState(() => _checkOut = picked);
  }

  Future<void> _save() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih karyawan terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final result = await AttendanceService().record(
      userId: _userId!,
      workDate: apiDate(_date),
      checkInTime: apiTime(_checkIn),
      checkOutTime: _checkOut == null ? null : apiTime(_checkOut!),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'].toString())),
    );

    if (result['success'] == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Absensi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _userId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Karyawan',
                    border: OutlineInputBorder(),
                  ),
                  items: _workers
                      .map(
                        (worker) => DropdownMenuItem<int>(
                          value: worker['id'] as int,
                          child: Text(
                            '${worker['name']} (${roleLabel(worker['role']?.toString())})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _userId = value),
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: AppColors.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  leading: const Icon(Icons.event_rounded),
                  title: const Text('Tanggal'),
                  subtitle: Text(formatWorkDate(apiDate(_date))),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: AppColors.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('Jam masuk'),
                  subtitle: Text(apiTime(_checkIn)),
                  onTap: _pickCheckIn,
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: AppColors.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Jam pulang'),
                  subtitle: Text(_checkOut == null ? 'Belum diisi' : apiTime(_checkOut!)),
                  trailing: _checkOut == null
                      ? null
                      : IconButton(
                          tooltip: 'Kosongkan',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _checkOut = null),
                        ),
                  onTap: _pickCheckOut,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Absensi yang Anda catat langsung berstatus terverifikasi.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SIMPAN ABSENSI'),
                ),
              ],
            ),
    );
  }
}
