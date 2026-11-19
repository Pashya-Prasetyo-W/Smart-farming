import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/incident_service.dart';
import '../../utils/search.dart';
import '../../widgets/search_field.dart';

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
          'Laporan Insiden',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: SearchField(
            hint: 'Cari jenis, lahan, pelapor, deskripsi...',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incidents == null || _incidents!.isEmpty
          ? const Center(child: Text('Belum ada laporan insiden.'))
          : incidents.isEmpty
          ? Center(child: Text('Tidak ada hasil untuk "$_query".'))
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
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
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
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    incident['type']
                                        .toString()
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    color: Colors.grey[600],
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
