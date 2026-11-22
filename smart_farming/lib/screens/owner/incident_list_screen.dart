import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/incident_service.dart';
import '../../utils/search.dart';
import '../../widgets/search_field.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';

class IncidentListScreen extends StatefulWidget {
  const IncidentListScreen({super.key});

  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen> {
  bool _isLoading = true;
  List<dynamic>? _incidents;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchIncidents();
  }

  void _fetchIncidents() async {
    final data = await IncidentService().getIncidents();
    
    if (!mounted) return;
    
    setState(() {
      _incidents = data;
      _isLoading = false;
    });
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
    final incidents = _filteredIncidents;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Laporan Insiden'
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SearchField(
            hint: 'Cari jenis, lahan, pelapor, deskripsi...',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incidents == null || _incidents!.isEmpty
          ? const EmptyState(message: 'Belum ada laporan insiden.')
          : incidents.isEmpty
          ? EmptyState(message: 'Tidak ada hasil untuk "$_query".', icon: Icons.search_off_rounded)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: incidents.length,
              itemBuilder: (context, index) {
                final incident = incidents[index];
                final mediaUrls = incident['media_urls'] as List<dynamic>;
                final imageUrl = mediaUrls.isNotEmpty ? mediaUrls[0] : null;

                final date = DateTime.parse(incident['reported_at']);
                final formattedDate = DateFormat('dd MMM yyyy, HH:mm')
                    .format(date);

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
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 150,
                                  color: AppColors.outline,
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Lahan: ${incident['land']['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Pelapor: ${incident['reporter']['name']}'),
                            const Divider(height: 24),
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
