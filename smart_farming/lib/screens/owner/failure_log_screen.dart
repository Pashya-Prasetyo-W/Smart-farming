import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/failure_log_service.dart';
import '../../services/incident_service.dart';
import '../../utils/search.dart';
import '../../widgets/search_field.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

class FailureLogScreen extends StatefulWidget {
  const FailureLogScreen({super.key});

  @override
  State<FailureLogScreen> createState() => _FailureLogScreenState();
}

class _FailureLogScreenState extends State<FailureLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Indikasi Gagal Panen'
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Analisis Cuaca', icon: Icon(Icons.cloud)),
            Tab(text: 'Laporan Lapangan', icon: Icon(Icons.warning)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_WeatherRiskTab(), _IncidentRiskTab()],
      ),
    );
  }
}

class _WeatherRiskTab extends StatefulWidget {
  @override
  State<_WeatherRiskTab> createState() => _WeatherRiskTabState();
}

class _WeatherRiskTabState extends State<_WeatherRiskTab> {
  bool _isLoading = true;
  bool _loadFailed = false;
  List<dynamic> _logs = [];
  Map<String, dynamic> _status = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final data = await FailureLogService().getOverview();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loadFailed = data == null;
      if (data != null) {
        _logs = data['logs'] as List<dynamic>;
        _status = data['status'] as Map<String, dynamic>;
      }
    });
  }

  List<dynamic> get _filteredLogs {
    return _logs.where((log) {
      return matchesSearch(_query, [
        log['planting']?['crop_name'],
        log['planting']?['land']?['name'],
        log['reason'],
        log['risk_score'],
      ]);
    }).toList();
  }

  List<Object> _groupByDate(List<dynamic> logs) {
    final items = <Object>[];
    String? currentKey;

    for (final log in logs) {
      final date = DateTime.parse(log['created_at']).toLocal();
      final key = DateFormat('dd MMM yyyy').format(date);
      if (key != currentKey) {
        items.add(key);
        currentKey = key;
      }
      items.add(log);
    }

    return items;
  }

  Widget _banner() {
    final score = int.tryParse(_status['current_score'].toString()) ?? 0;
    final isHigh = score > 70;
    final hasRisk = score > 0;
    final color = hasRisk
        ? (isHigh ? AppColors.danger : AppColors.warning)
        : AppColors.primary;
    final lastRunAt = _status['last_run_at'];
    final lastRun = _status['last_run'] as Map<String, dynamic>?;
    final failed = int.tryParse('${lastRun?['failed'] ?? 0}') ?? 0;
    final isStale = _status['is_stale'] == true;

    final runText = lastRunAt == null
        ? 'Analisis otomatis belum pernah berjalan.'
        : 'Analisis terakhir: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(lastRunAt).toLocal())}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: color, width: 2)),
      ),
      child: Column(
        children: [
          Text(
            hasRisk ? 'Risiko Cuaca Saat Ini' : 'Aman',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          if (hasRisk)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            )
          else
            Icon(Icons.verified_rounded, size: 48, color: color),
          const SizedBox(height: 8),
          Text(
            hasRisk
                ? 'Dari analisis terbaru pada siklus yang masih berjalan.'
                : 'Tidak ada risiko cuaca pada analisis terbaru.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Text(
            runText,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (failed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$failed lahan gagal diambil data cuacanya pada analisis terakhir.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          if (isStale)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: const Text(
                'Analisis otomatis belum berjalan lebih dari 36 jam. Periksa penjadwal (cron) di server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logCard(dynamic log) {
    final score = int.tryParse(log['risk_score'].toString()) ?? 0;
    final planting = log['planting'];
    final finished = planting != null && planting['status'] != 'berjalan';
    final crop = planting?['crop_name'] ?? 'Siklus tidak tersedia';
    final land = planting?['land']?['name'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  label: 'Risiko: $score%',
                  color: score > 70 ? AppColors.danger : AppColors.warning,
                ),
                if (finished) ...[
                  const SizedBox(width: 8),
                  const StatusPill(
                    label: 'Siklus selesai',
                    color: AppColors.textMuted,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              land == null ? '$crop' : '$crop - $land',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${log['reason']}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_logs.isEmpty) {
      return const EmptyState(
        message: 'Belum ada riwayat risiko cuaca.',
        icon: Icons.cloud_done_rounded,
      );
    }

    final logs = _filteredLogs;
    if (logs.isEmpty) {
      return EmptyState(
        message: 'Tidak ada hasil untuk "$_query".',
        icon: Icons.search_off_rounded,
      );
    }

    final items = _groupByDate(logs);

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            );
          }
          return _logCard(item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return ErrorState(
        message: 'Gagal memuat analisis cuaca.',
        onRetry: () {
          setState(() => _isLoading = true);
          _fetch();
        },
      );
    }

    return Column(
      children: [
        _banner(),
        SearchField(
          hint: 'Cari tanaman, lahan, alasan...',
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          onChanged: (value) => setState(() => _query = value),
        ),
        Expanded(child: _list()),
      ],
    );
  }
}

class _IncidentRiskTab extends StatefulWidget {
  @override
  State<_IncidentRiskTab> createState() => _IncidentRiskTabState();
}

class _IncidentRiskTabState extends State<_IncidentRiskTab> {
  bool _isLoading = true;
  List<dynamic>? _incidents;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    final data = await IncidentService().getIncidents();
    if (mounted) {
      setState(() {
        _incidents = data;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredIncidents {
    return (_incidents ?? []).where((incident) {
      return matchesSearch(_query, [
        incident['type'],
        incident['description'],
        incident['land']?['name'],
        incident['reporter']?['name'],
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_incidents == null || _incidents!.isEmpty)
      return const Center(
        child: Text('Belum ada laporan insiden dari lapangan.'),
      );

    final incidents = _filteredIncidents;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: SearchField(
          hint: 'Cari jenis, lahan, pelapor, deskripsi...',
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: incidents.isEmpty
          ? EmptyState(message: 'Tidak ada hasil untuk "$_query".', icon: Icons.search_off_rounded)
          : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: incidents.length,
      itemBuilder: (context, index) {
        final incident = incidents[index];
        final mediaUrls = incident['media_urls'] as List<dynamic>;
        final imageUrl = mediaUrls.isNotEmpty ? mediaUrls[0] : null;
        final date = DateTime.parse(incident['reported_at']);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            incident['type']
                                .toString()
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(date),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lahan: ${incident['land']['name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Pelapor: ${incident['reporter']['name']}',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const Divider(),
                    Text(incident['description']),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
    );
  }
}
