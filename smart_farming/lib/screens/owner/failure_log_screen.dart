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
  List<dynamic>? _logs;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    final data = await FailureLogService().getLogs();
    if (mounted) {
      setState(() {
        _logs = data;
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredLogs {
    return (_logs ?? []).where((log) {
      return matchesSearch(_query, [
        log['planting']?['crop_name'],
        log['planting']?['land']?['name'],
        log['reason'],
        log['risk_score'],
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_logs == null || _logs!.isEmpty)
      return const Center(
        child: Text('Tidak ada indikasi gagal panen cuaca. Aman!'),
      );

    double highestRisk = _logs!
        .map((e) => double.parse(e['risk_score'].toString()))
        .reduce((a, b) => a > b ? a : b);
    final isHighRisk = highestRisk > 70;
    final logs = _filteredLogs;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isHighRisk ? AppColors.danger.withValues(alpha: 0.08) : AppColors.warning.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(
                color: isHighRisk ? AppColors.danger : AppColors.warning,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Risiko Cuaca Tertinggi',
                style: TextStyle(fontSize: 16, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    highestRisk.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isHighRisk ? AppColors.danger : AppColors.warning,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isHighRisk ? AppColors.danger : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SearchField(
          hint: 'Cari tanaman, lahan, alasan...',
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          onChanged: (value) => setState(() => _query = value),
        ),
        Expanded(
          child: logs.isEmpty
              ? EmptyState(message: 'Tidak ada hasil untuk "$_query".', icon: Icons.search_off_rounded)
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final score = double.parse(log['risk_score'].toString());
              final isHigh = score > 70;
              final date = DateTime.parse(log['created_at']);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
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
                              color: isHigh
                                  ? AppColors.danger.withValues(alpha: 0.16)
                                  : AppColors.warning.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Risiko: ${score.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: isHigh
                                    ? AppColors.danger
                                    : AppColors.warning,
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
                      const SizedBox(height: 12),
                      Text(
                        'Lahan: ${log['planting']['crop_name']} - ${log['planting']['land']['name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      Text('Alasan: ${log['reason']}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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
