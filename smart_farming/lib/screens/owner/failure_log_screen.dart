import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/failure_log_service.dart';
import '../../services/incident_service.dart'; // Import service insiden

class FailureLogScreen extends StatefulWidget {
  const FailureLogScreen({super.key});

  @override
  State<FailureLogScreen> createState() => _FailureLogScreenState();
}

class _FailureLogScreenState extends State<FailureLogScreen> with SingleTickerProviderStateMixin {
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
        title: const Text('Indikasi Gagal Panen', style: TextStyle(color: Colors.white)), 
        backgroundColor: const Color(0xFF2E7D32), 
        iconTheme: const IconThemeData(color: Colors.white),
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
        children: [
          _WeatherRiskTab(),
          _IncidentRiskTab(),
        ],
      ),
    );
  }
}

// --- TAB 1: ANALISIS CUACA ---
class _WeatherRiskTab extends StatefulWidget {
  @override
  State<_WeatherRiskTab> createState() => _WeatherRiskTabState();
}

class _WeatherRiskTabState extends State<_WeatherRiskTab> {
  bool _isLoading = true;
  List<dynamic>? _logs;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    final data = await FailureLogService().getLogs();
    if (mounted) {
      setState(() { _logs = data; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_logs == null || _logs!.isEmpty) return const Center(child: Text('Tidak ada indikasi gagal panen cuaca. Aman!'));

    double highestRisk = _logs!.map((e) => double.parse(e['risk_score'].toString())).reduce((a, b) => a > b ? a : b);
    final isHighRisk = highestRisk > 70;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isHighRisk ? Colors.red[50] : Colors.orange[50],
            border: Border(bottom: BorderSide(color: isHighRisk ? Colors.red : Colors.orange, width: 2)),
          ),
          child: Column(
            children: [
              Text('Risiko Cuaca Tertinggi', style: TextStyle(fontSize: 16, color: Colors.grey[800])),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(highestRisk.toStringAsFixed(0), style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: isHighRisk ? Colors.red[800] : Colors.orange[800])),
                  Text('%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isHighRisk ? Colors.red[800] : Colors.orange[800])),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _logs!.length,
            itemBuilder: (context, index) {
              final log = _logs![index];
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: isHigh ? Colors.red[100] : Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                            child: Text('Risiko: ${score.toStringAsFixed(0)}%', style: TextStyle(color: isHigh ? Colors.red[800] : Colors.orange[800], fontWeight: FontWeight.bold)),
                          ),
                          Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Lahan: ${log['planting']['crop_name']} - ${log['planting']['land']['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
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

// --- TAB 2: LAPORAN INSIDEN ---
class _IncidentRiskTab extends StatefulWidget {
  @override
  State<_IncidentRiskTab> createState() => _IncidentRiskTabState();
}

class _IncidentRiskTabState extends State<_IncidentRiskTab> {
  bool _isLoading = true;
  List<dynamic>? _incidents;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    final data = await IncidentService().getIncidents();
    if (mounted) {
      setState(() { _incidents = data; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_incidents == null || _incidents!.isEmpty) return const Center(child: Text('Belum ada laporan insiden dari lapangan.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _incidents!.length,
      itemBuilder: (context, index) {
        final incident = _incidents![index];
        final mediaUrls = incident['media_urls'] as List<dynamic>;
        final imageUrl = mediaUrls.isNotEmpty ? mediaUrls[0] : null;
        final date = DateTime.parse(incident['reported_at']);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(incident['type'].toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Lahan: ${incident['land']['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Pelapor: ${incident['reporter']['name']}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    const Divider(),
                    Text(incident['description']),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}