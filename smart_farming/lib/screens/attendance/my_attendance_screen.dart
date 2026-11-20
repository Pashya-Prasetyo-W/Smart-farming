import 'package:flutter/material.dart';

import '../../services/attendance_service.dart';
import '../../utils/attendance_format.dart';
import '../../widgets/attendance_status_chip.dart';
import '../../widgets/reason_dialog.dart';

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  final _service = AttendanceService();

  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  Map<String, dynamic>? _today;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([_service.today(), _service.mine()]);
    if (!mounted) return;

    final today = results[0];
    final history = results[1];

    setState(() {
      _isLoading = false;
      if (today['success'] == true && history['success'] == true) {
        _loadError = null;
        _today = today['data'] is Map<String, dynamic>
            ? today['data'] as Map<String, dynamic>
            : null;
        _history = (history['data'] as List?) ?? [];
      } else {
        _loadError = (today['success'] != true ? today : history)['message']
            .toString();
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    final result = await action();
    if (!mounted) return;

    setState(() => _isBusy = false);
    _toast(result['message'].toString().isEmpty
        ? (result['success'] == true ? 'Berhasil.' : 'Gagal.')
        : result['message'].toString());

    if (result['success'] == true) await _load();
  }

  Future<void> _object(Map<String, dynamic> item) async {
    final note = await askReason(
      context,
      title: 'Ajukan Keberatan',
      label: 'Alasan keberatan',
      confirmLabel: 'Ajukan',
    );
    if (note == null) return;
    await _run(() => _service.object(item['id'] as int, note));
  }

  Widget _todayCard() {
    final today = _today;
    final checkedIn = today != null;
    final checkedOut = checkedIn && today['check_out_at'] != null;
    final editable = checkedIn && today['status'] == 'menunggu';

    String title;
    if (!checkedIn) {
      title = 'Anda belum absen hari ini';
    } else if (!checkedOut) {
      title = 'Sedang bekerja';
    } else {
      title = 'Absensi hari ini lengkap';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (checkedIn) AttendanceStatusChip(status: today['status']?.toString()),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatWorkDate(DateTime.now().toIso8601String())),
            if (checkedIn) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _timeBlock('Masuk', formatClock(today['check_in_at']))),
                  Expanded(
                    child: _timeBlock(
                      'Pulang',
                      checkedOut ? formatClock(today['check_out_at']) : '--:--',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (!checkedIn)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : () => _run(_service.checkIn),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('ABSEN MASUK'),
                ),
              )
            else if (!checkedOut && editable)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : () => _run(_service.checkOut),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('ABSEN PULANG'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timeBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _historyTile(Map<String, dynamic> item) {
    final status = item['status']?.toString();
    final canObject = status == 'ditolak' &&
        item['is_final'] != true &&
        ((item['objection_count'] as num?) ?? 0) < 2;
    final checkOut = item['check_out_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatWorkDate(item['work_date']),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                AttendanceStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${formatClock(item['check_in_at'])} - '
              '${checkOut == null ? '--:--' : formatClock(checkOut)}'
              '${item['source'] == 'dicatat' ? '  •  Dicatat atasan' : ''}',
            ),
            if (status == 'ditolak' && item['reject_reason'] != null) ...[
              const SizedBox(height: 6),
              Text(
                'Alasan ditolak: ${item['reject_reason']}',
                style: const TextStyle(color: Color(0xFFC62828)),
              ),
            ],
            if (status == 'keberatan' && item['objection_note'] != null) ...[
              const SizedBox(height: 6),
              Text('Keberatan Anda: ${item['objection_note']}'),
            ],
            if (status == 'ditolak' && item['is_final'] == true) ...[
              const SizedBox(height: 6),
              const Text(
                'Keputusan final.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            if (canObject) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: _isBusy ? null : () => _object(item),
                  child: const Text('Ajukan Keberatan'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Absensi Saya')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            setState(() => _isLoading = true);
                            _load();
                          },
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _todayCard(),
                      const SizedBox(height: 16),
                      const Text(
                        'Riwayat 30 Hari Terakhir',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_history.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Belum ada riwayat absensi.')),
                        )
                      else
                        ..._history.map(
                          (item) => _historyTile(item as Map<String, dynamic>),
                        ),
                    ],
                  ),
                ),
    );
  }
}
