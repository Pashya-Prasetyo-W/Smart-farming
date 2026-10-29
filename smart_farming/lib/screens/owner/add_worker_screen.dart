import 'package:flutter/material.dart';

import '../../services/worker_service.dart';

class AddWorkerScreen extends StatefulWidget {
  const AddWorkerScreen({super.key});

  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _healthDescController = TextEditingController();
  final _foodDescController = TextEditingController();

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);

  final Map<String, bool> _workDays = {
    'senin': true,
    'selasa': true,
    'rabu': true,
    'kamis': true,
    'jumat': true,
    'sabtu': false,
    'minggu': false,
  };

  bool _healthInsurance = false;
  bool _foodAllowance = false;
  bool _isLoading = false;
  bool _isObscure = true;

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
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama, Email, dan Password wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    List<String> selectedDays = _workDays.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final data = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
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

    final success = await WorkerService().createWorker(data);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun Buruh berhasil dibuat!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat akun buruh. Cek console.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tambah Buruh',
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
                labelText: 'Password',
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
                    labelText: 'Detail Jaminan',
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
                    labelText: 'Detail Tunjangan',
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
                      'SIMPAN DATA BURUH',
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
