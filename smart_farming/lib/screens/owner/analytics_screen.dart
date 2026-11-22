import 'package:flutter/material.dart';

import '../../services/analytics_service.dart';
import '../../utils/attendance_format.dart';
import '../../utils/rupiah.dart';
import 'planting_summary_screen.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFC62828);
const _orange = Color(0xFFEF6C00);

String _money(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '') ?? 0;
  return '${number < 0 ? '-' : ''}${Rupiah.format(number.abs())}';
}

Color _signColor(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '') ?? 0;
  if (number < 0) return _red;
  if (number > 0) return _green;
  return Colors.grey;
}

String _kg(dynamic value) {
  final number = num.tryParse(value?.toString() ?? '') ?? 0;
  return number == number.roundToDouble()
      ? '${number.toInt()} kg'
      : '${number.toStringAsFixed(2)} kg';
}

String _statusText(String? status) {
  switch (status) {
    case 'panen':
      return 'Panen';
    case 'gagal':
      return 'Gagal';
    default:
      return 'Berjalan';
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'panen':
      return _green;
    case 'gagal':
      return _red;
    default:
      return _orange;
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Analitik Laba & Risiko',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: _green,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Laba', icon: Icon(Icons.trending_up)),
              Tab(text: 'Risiko', icon: Icon(Icons.crisis_alert)),
            ],
          ),
        ),
        body: const TabBarView(children: [_ProfitTab(), _RiskTab()]),
      ),
    );
  }
}

class _ProfitTab extends StatefulWidget {
  const _ProfitTab();

  @override
  State<_ProfitTab> createState() => _ProfitTabState();
}

class _ProfitTabState extends State<_ProfitTab> {
  final _service = AnalyticsService();

  bool _isLoading = true;
  String? _loadError;
  Map<String, dynamic>? _data;
  String? _status;
  bool _byLand = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.profit(status: _status);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        _loadError = null;
        _data = result['data'] as Map<String, dynamic>;
      } else {
        _loadError = result['message'].toString();
      }
    });
  }

  Widget _line(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overall(Map<String, dynamic> overall) {
    final net = overall['net_profit'];

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _line('Pendapatan', _money(overall['income'])),
            _line('Biaya siklus', _money(overall['cycle_cost'])),
            _line(
              'Laba siklus',
              _money(overall['cycle_profit']),
              color: _signColor(overall['cycle_profit']),
              bold: true,
            ),
            if (overall['unallocated_cost'] != null) ...[
              const Divider(),
              _line(
                'Biaya umum (tanpa siklus)',
                _money(overall['unallocated_cost']),
              ),
              _line(
                'Laba bersih',
                _money(net),
                color: _signColor(net),
                bold: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cycleCard(Map<String, dynamic> cycle) {
    final status = cycle['status']?.toString();
    final margin = cycle['margin_percent'];
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlantingSummaryScreen(
              plantingId: cycle['planting_id'] as int,
            ),
          ),
        ).then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${cycle['crop_name']} - ${cycle['land_name'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${formatShortDate(cycle['plant_date'])} • ${cycle['duration_days']} hari',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              _line('Pendapatan', _money(cycle['income'])),
              _line('Biaya', _money(cycle['cost'])),
              _line(
                'Laba',
                _money(cycle['profit']),
                color: _signColor(cycle['profit']),
                bold: true,
              ),
              if (margin != null)
                _line('Margin', '${num.parse(margin.toString()).toStringAsFixed(1)}%'),
              if (num.parse(cycle['harvested_kg'].toString()) > 0)
                _line('Panen', _kg(cycle['harvested_kg'])),
              if (cycle['hpp_per_kg'] != null)
                _line('HPP per kg', _money(cycle['hpp_per_kg'])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _landCard(Map<String, dynamic> land) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              land['land_name']?.toString() ?? '-',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${land['cycles']} siklus • ${land['running']} berjalan • '
              '${land['harvested']} panen • ${land['failed']} gagal',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _line('Pendapatan', _money(land['income'])),
            _line('Biaya', _money(land['cost'])),
            _line(
              'Laba',
              _money(land['profit']),
              color: _signColor(land['profit']),
              bold: true,
            ),
            if (land['avg_profit_per_cycle'] != null)
              _line('Rata-rata laba per siklus', _money(land['avg_profit_per_cycle'])),
            if (land['profit_per_ha'] != null)
              _line('Laba per hektar', _money(land['profit_per_ha'])),
            if (num.parse(land['harvested_kg'].toString()) > 0)
              _line('Total panen', _kg(land['harvested_kg'])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) return Center(child: Text(_loadError!));

    final data = _data!;
    final cycles = (data['cycles'] as List).cast<Map<String, dynamic>>();
    final lands = (data['lands'] as List).cast<Map<String, dynamic>>();
    final items = _byLand ? lands : cycles;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _overall(data['overall'] as Map<String, dynamic>),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Per Siklus')),
                ButtonSegment(value: true, label: Text('Per Lahan')),
              ],
              selected: {_byLand},
              onSelectionChanged: (value) =>
                  setState(() => _byLand = value.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final option in const [
                  [null, 'Semua'],
                  ['berjalan', 'Berjalan'],
                  ['panen', 'Panen'],
                  ['gagal', 'Gagal'],
                ])
                  ChoiceChip(
                    label: Text(option[1]!),
                    selected: _status == option[0],
                    onSelected: (_) {
                      setState(() {
                        _status = option[0];
                        _isLoading = true;
                      });
                      _load();
                    },
                  ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('Belum ada data siklus tanam.')),
            )
          else
            ...items.map(_byLand ? _landCard : _cycleCard),
        ],
      ),
    );
  }
}

class _RiskTab extends StatefulWidget {
  const _RiskTab();

  @override
  State<_RiskTab> createState() => _RiskTabState();
}

class _RiskTabState extends State<_RiskTab> {
  final _service = AnalyticsService();

  bool _isLoading = true;
  String? _loadError;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.risk();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _loadError = null;
        _items = ((result['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      } else {
        _loadError = result['message'].toString();
      }
    });
  }

  Color _levelColor(String? level) {
    switch (level) {
      case 'tinggi':
        return _red;
      case 'sedang':
        return _orange;
      default:
        return _green;
    }
  }

  String _levelText(String? level) {
    switch (level) {
      case 'tinggi':
        return 'Risiko tinggi';
      case 'sedang':
        return 'Risiko sedang';
      default:
        return 'Risiko rendah';
    }
  }

  String _harvestText(int days) {
    if (days < 0) return 'Lewat ${-days} hari dari perkiraan panen';
    if (days == 0) return 'Perkiraan panen hari ini';
    return 'Perkiraan panen $days hari lagi';
  }

  Widget _card(Map<String, dynamic> item) {
    final level = item['level']?.toString();
    final color = _levelColor(level);
    final score = (item['score'] as num).toInt();
    final land = item['land'] as Map<String, dynamic>?;
    final factors = (item['factors'] as List).cast<Map<String, dynamic>>();
    final incidents = item['incidents'] as Map<String, dynamic>;
    final recent = (incidents['recent'] as List).cast<Map<String, dynamic>>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['crop_name']} - ${land?['name'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _levelText(level),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            Text(
              _harvestText((item['days_to_harvest'] as num).toInt()),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (factors.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Tidak ada faktor risiko saat ini.'),
              )
            else ...[
              const SizedBox(height: 8),
              const Text(
                'Faktor risiko:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...factors.map(
                (factor) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('+${factor['points']}  ${factor['label']}'),
                ),
              ),
            ],
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Kejadian terbaru di lahan ini:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...recent.map(
                (incident) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '- ${incident['description']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) return Center(child: Text(_loadError!));

    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('Tidak ada siklus tanam yang sedang berjalan.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: _items.length,
              itemBuilder: (context, index) => _card(_items[index]),
            ),
    );
  }
}
