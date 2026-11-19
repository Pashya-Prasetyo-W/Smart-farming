import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/worker_service.dart';
import '../../utils/password_generator.dart';
import '../../widgets/benefit_editor.dart';
import '../../widgets/wage_editor.dart';

class AddWorkerScreen extends StatefulWidget {
  const AddWorkerScreen({super.key});

  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<BenefitEntry> _benefits = [];
  final WageDraft _wage = WageDraft();

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

  bool _isLoading = false;
  bool _isObscure = true;

  String _role = 'buruh';
  bool _canChooseRole = false;

  @override
  void initState() {
    super.initState();
    _loadActorRole();
  }

  Future<void> _loadActorRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _canChooseRole = prefs.getString('role') == 'pemilik');
  }

  String get _roleLabel => _role == 'mandor' ? 'Mandor' : 'Buruh';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    BenefitEntry.disposeAll(_benefits);
    _wage.dispose();
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

    if (_role == 'mandor' && BenefitEntry.hasBlank(_benefits)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama jaminan tidak boleh kosong.')),
      );
      return;
    }

    if (_canChooseRole && _role == 'mandor' && _wage.hasInvalidAllowance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama dan nominal tunjangan wajib diisi.'),
        ),
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
      'password': _passwordController.text.trim(),
      'role': _role,
      'schedule': {
        'start_time': _formatTime(_startTime),
        'end_time': _formatTime(_endTime),
        'work_days': selectedDays,
      },
      if (_role == 'mandor') 'benefits': BenefitEntry.payload(_benefits),
      if (_canChooseRole && _wage.payload() != null) 'wage': _wage.payload(),
      if (_canChooseRole && _role == 'mandor')
        'allowances': _wage.allowancePayload(),
    };

    final success = await WorkerService().createWorker(data);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Akun $_roleLabel berhasil dibuat!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat akun $_roleLabel. Pastikan email belum terdaftar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tambah $_roleLabel',
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
            if (_canChooseRole) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'buruh', label: Text('Buruh')),
                  ButtonSegment(value: 'mandor', label: Text('Mandor')),
                ],
                selected: {_role},
                onSelectionChanged: (v) => setState(() {
                  _role = v.first;
                  _wage.useRole(_role);
                }),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Lengkap $_roleLabel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email $_roleLabel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: 'Password Sementara',
                helperText: 'Pengguna wajib menggantinya saat login pertama.',
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

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _passwordController.text = PasswordGenerator.generate();
                  _isObscure = false;
                }),
                icon: const Icon(Icons.autorenew, size: 18),
                label: const Text('Buat password acak'),
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

            if (_canChooseRole) ...[
              const Divider(height: 32),
              const Text(
                'Upah',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              WageEditor(draft: _wage, role: _role),
            ],

            if (_role == 'mandor') ...[
              const Divider(height: 32),
              const Text(
                'Jaminan & Benefit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              BenefitEditor(entries: _benefits),
            ],

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
                  : Text(
                      'SIMPAN DATA ${_roleLabel.toUpperCase()}',
                      style: const TextStyle(
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
