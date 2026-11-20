import 'package:flutter/material.dart';

import '../../services/report_review_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/search.dart';
import '../../widgets/attendance_status_chip.dart';
import '../../widgets/reason_dialog.dart';
import '../../widgets/search_field.dart';
import '../owner/task_detail_screen.dart';

class ReportReviewScreen extends StatefulWidget {
  const ReportReviewScreen({super.key});

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  final _service = ReportReviewService();

  bool _isLoading = true;
  bool _isBusy = false;
  String? _loadError;
  List<dynamic> _queue = [];
  List<dynamic> _history = [];
  String _query = '';
  String? _statusFilter;

  static const _statusOptions = <String?>[
    null,
    'menunggu',
    'terverifikasi',
    'ditolak',
    'keberatan',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _service.queue(),
      _service.history(status: _statusFilter),
    ]);
    if (!mounted) return;

    final queue = results[0];
    final history = results[1];

    setState(() {
      _isLoading = false;
      if (queue['success'] == true && history['success'] == true) {
        _loadError = null;
        _queue = (queue['data'] as List?) ?? [];
        _history = (history['data'] as List?) ?? [];
      } else {
        _loadError =
            (queue['success'] != true ? queue : history)['message'].toString();
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(Future<Map<String, dynamic>> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    final result = await action();
    if (!mounted) return;

    setState(() => _isBusy = false);
    _toast(
      result['message'].toString().isEmpty
          ? (result['success'] == true ? 'Berhasil.' : 'Gagal.')
          : result['message'].toString(),
    );

    if (result['success'] == true) await _load();
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final reason = await askReason(
      context,
      title: 'Tolak Laporan',
      label: 'Alasan penolakan',
      confirmLabel: 'Tolak',
    );
    if (reason == null) return;
    await _act(() => _service.reject(item['id'] as int, reason));
  }

  void _openTask(Map<String, dynamic> item) {
    final task = item['task'] as Map<String, dynamic>?;
    if (task == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(taskId: task['id'] as int),
      ),
    ).then((_) => _load());
  }

  String _reportedAt(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length < 16) return '-';
    return '${formatWorkDate(text.substring(0, 10))}, ${text.substring(11, 16)}';
  }

  bool _matches(Map<String, dynamic> item) {
    final task = item['task'] as Map<String, dynamic>?;
    final assignee = task?['assignee'] as Map<String, dynamic>?;
    return matchesSearch(_query, [
      task?['title'],
      assignee?['name'],
      roleLabel(assignee?['role']?.toString()),
      statusLabel(item['review_status']?.toString()),
      item['notes'],
    ]);
  }

  Widget _tile(Map<String, dynamic> item, {required bool actionable}) {
    final task = item['task'] as Map<String, dynamic>?;
    final assignee = task?['assignee'] as Map<String, dynamic>?;
    final status = item['review_status']?.toString();
    final reviewer = item['reviewer'] as Map<String, dynamic>?;
    final media = item['media_urls'];
    final notes = item['notes']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTask(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task?['title']?.toString() ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  AttendanceStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Pelaksana: ${assignee?['name'] ?? '-'} (${roleLabel(assignee?['role']?.toString())})',
              ),
              Text('Dilaporkan: ${_reportedAt(item['reported_at'])}'),
              if (media is List && media.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    media.first.toString(),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 60,
                      color: Colors.grey[300],
                      child: const Center(child: Text('Gagal memuat gambar')),
                    ),
                  ),
                ),
              ],
              if (notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Catatan: $notes'),
                ),
              if (item['escalated_at'] != null && actionable)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Melewati 24 jam, dinaikkan ke pemilik.',
                    style: TextStyle(color: Color(0xFFEF6C00), fontSize: 12),
                  ),
                ),
              if (status == 'keberatan' && item['objection_note'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Keberatan: ${item['objection_note']}'),
                ),
              if (status == 'ditolak' && item['reject_reason'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Ditolak: ${item['reject_reason']}'
                    '${item['is_final'] == true ? ' (final)' : ''}',
                    style: const TextStyle(color: Color(0xFFC62828)),
                  ),
                ),
              if (!actionable && reviewer != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Diproses oleh ${reviewer['name']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              if (actionable) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isBusy ? null : () => _reject(item),
                        child: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isBusy
                            ? null
                            : () => _act(
                                () => _service.verify(item['id'] as int),
                              ),
                        child: const Text('Verifikasi'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(
    List<dynamic> source, {
    required bool actionable,
    required String empty,
  }) {
    final items = source.cast<Map<String, dynamic>>().where(_matches).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text(_query.isEmpty ? empty : 'Tidak ada hasil.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: items.length,
              itemBuilder: (_, i) => _tile(items[i], actionable: actionable),
            ),
    );
  }

  Widget _statusFilterBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _statusOptions.map((option) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option == null ? 'Semua' : statusLabel(option)),
              selected: _statusFilter == option,
              onSelected: (_) {
                setState(() {
                  _statusFilter = option;
                  _isLoading = true;
                });
                _load();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verifikasi Laporan'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Perlu Diverifikasi (${_queue.length})'),
              const Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 12),
            SearchField(
              hint: 'Cari tugas, pelaksana, atau status',
              onChanged: (value) => setState(() => _query = value),
            ),
            Expanded(
              child: _isLoading
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
                  : TabBarView(
                      children: [
                        _list(
                          _queue,
                          actionable: true,
                          empty: 'Tidak ada laporan yang menunggu verifikasi.',
                        ),
                        Column(
                          children: [
                            _statusFilterBar(),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _list(
                                _history,
                                actionable: false,
                                empty: 'Belum ada riwayat laporan.',
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
}
