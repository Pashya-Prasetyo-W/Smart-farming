import 'package:flutter/material.dart';
import '../../services/worker_service.dart';

class EditWorkerScreen extends StatefulWidget {
  final Map<String, dynamic> worker;

  const EditWorkerScreen({super.key, required this.worker});

  @override
  State<EditWorkerScreen> createState() => _EditWorkerScreenState();
}

class _EditWorkerScreenState extends State<EditWorkerScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  late final TextEditingController _healthDescController;
  late final TextEditingController _foodDescController;

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);

  final Map<String, bool> _workDays = {
    'senin': false,
    'selasa': false,
    'rabu': false,
    'kamis': false,
    'jumat': false,
    'sabtu': false,
    'minggu': false,
  };

  bool _healthInsurance = false;
  bool _foodAllowance = false;
  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void initState() {
    super.initState();
    
    // Inisialisasi controller dengan data worker yang ada
    _nameController = TextEditingController(text: widget.worker['name'] ?? '');
    _emailController = TextEditingController(text: widget.worker['email'] ?? '');
    
    final benefit = widget.worker['benefit'];
    _healthInsurance = benefit != null && benefit['health_insurance'] == true;
    _foodAllowance = benefit != null && benefit['food_allowance'] == true;

    _healthDescController = TextEditingController(
      text: benefit?['health_insurance_desc'] ?? '',
    );
    _foodDescController = TextEditingController(
      text: benefit?['food_allowance_desc'] ?? '',
    );

    // Parse jam kerja jika ada
    final schedule = widget.worker['schedule'];
    if (schedule != null) {
      if (schedule['start_time'] != null) {
        final startTimeParts = schedule['start_time'].toString().split(':');
        if (startTimeParts.length >= 2) {
          _startTime = TimeOfDay(
            hour: int.parse(startTimeParts[0]),
            minute: int.parse(startTimeParts[1]),
          );
        }
      }
      if (schedule['end_time'] != null) {
        final endTimeParts = schedule['end_time'].toString().split(':');
        if (endTimeParts.length >= 2) {
          _endTime = TimeOfDay(
            hour: int.parse(endTimeParts[0]),
            minute: int.parse(endTimeParts[1]),
          );
        }
      }

      // Parse hari kerja jika ada
      if (schedule['work_days'] != null) {
        final List<dynamic> days = schedule['work_days'];
        for (var day in days) {
          if (_workDays.containsKey(day.toString().toLowerCase())) {
            _workDays[day.toString().toLowerCase()] = true;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _healthDescController.dispose();
    _foodDescController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  void _submit() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Email wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    List<String> selectedDays = _workDays.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'schedule': {
        'start_time': _formatTime(_startTime),
        'end_time': _formatTime(_endTime),
        'work_days': selectedDays,
      },
      'benefit': {
        'health_insurance': _healthInsurance ? 1 : 0,
        'health_insurance_desc': _healthInsurance
            ? _healthDescController.text.trim()
            : null,
        'food_allowance': _foodAllowance ? 1 : 0,
        'food_allowance_desc': _foodAllowance
            ? _foodDescController.text.trim()
            : null,
      },
    };

    // Jika password diisi, sertakan ke dalam data pembaruan
    if (_passwordController.text.isNotEmpty) {
      data['password'] = _passwordController.text.trim();
    }

    final int workerId = widget.worker['id'];
    final success = await WorkerService().updateWorker(workerId, data);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data Buruh berhasil diperbarui!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui data buruh. Cek console.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Buruh',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Akun',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap Buruh',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Buruh',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: 'Password Baru (Opsional)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscure = !_isObscure;
                    });
                  },
                ),
              ),
            ),

            const Divider(height: 32),

            const Text(
              'Jadwal Kerja',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Jam Mulai'),
                    subtitle: Text(_startTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) setState(() => _startTime = time);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Jam Selesai'),
                    subtitle: Text(_endTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) setState(() => _endTime = time);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Hari Kerja:'),
            Wrap(
              spacing: 8,
              children: _workDays.keys.map((day) {
                return FilterChip(
                  label: Text(day.toUpperCase()),
                  selected: _workDays[day]!,
                  onSelected: (selected) {
                    setState(() => _workDays[day] = selected);
                  },
                  selectedColor: const Color(0xFFC8E6C9),
                );
              }).toList(),
            ),

            const Divider(height: 32),

            const Text(
              'Jaminan & Benefit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Jaminan Kesehatan'),
              value: _healthInsurance,
              activeThumbColor: const Color(0xFF2E7D32),
              onChanged: (val) => setState(() => _healthInsurance = val),
            ),
            if (_healthInsurance)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: TextField(
                  controller: _healthDescController,
                  decoration: const InputDecoration(
                    labelText: 'Detail Jaminan (misal: BPJS, Nominal)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

            SwitchListTile(
              title: const Text('Tunjangan Makan'),
              value: _foodAllowance,
              activeThumbColor: const Color(0xFF2E7D32),
              onChanged: (val) => setState(() => _foodAllowance = val),
            ),
            if (_foodAllowance)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: TextField(
                  controller: _foodDescController,
                  decoration: const InputDecoration(
                    labelText: 'Detail Tunjangan (misal: Rp 20.000/hari)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SIMPAN PERUBAHAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}