import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/worker_service.dart';
import '../../utils/password_generator.dart';
import '../../widgets/benefit_editor.dart';
import '../../widgets/wage_editor.dart';
import '../../theme/app_theme.dart';

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
  final List<BenefitEntry> _benefits = [];
  late final WageDraft _wage;
  bool _isOwner = false;

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

  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.worker['name'] ?? '');
    _emailController = TextEditingController(
      text: widget.worker['email'] ?? '',
    );

    _benefits.addAll(BenefitEntry.fromList(widget.worker['benefits']));
    _wage = WageDraft.fromWorker(widget.worker);
    _loadActorRole();

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
    BenefitEntry.disposeAll(_benefits);
    _wage.dispose();
    super.dispose();
  }

  Future<void> _loadActorRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isOwner = prefs.getString('role') == 'pemilik');
  }

  bool get _isMandor => widget.worker['role'] == 'mandor';

  String get _roleLabel => _isMandor ? 'Mandor' : 'Buruh';

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

    if (_isMandor && BenefitEntry.hasBlank(_benefits)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama jaminan tidak boleh kosong.')),
      );
      return;
    }

    if (_isOwner && _isMandor && _wage.hasInvalidAllowance) {
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
      'schedule': {
        'start_time': _formatTime(_startTime),
        'end_time': _formatTime(_endTime),
        'work_days': selectedDays,
      },
      if (_isMandor) 'benefits': BenefitEntry.payload(_benefits),
      if (_isOwner && _wage.payload() != null) 'wage': _wage.payload(),
      if (_isOwner && _isMandor) 'allowances': _wage.allowancePayload(),
    };

    if (_passwordController.text.isNotEmpty) {
      data['password'] = _passwordController.text.trim();
    }

    final int workerId = widget.worker['id'];
    final success = await WorkerService().updateWorker(workerId, data);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data $_roleLabel berhasil diperbarui!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui data $_roleLabel.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit $_roleLabel'),
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
                labelText: 'Password Baru (Opsional)',
                helperText:
                    'Password saat ini tersimpan terenkripsi sehingga tidak dapat ditampilkan. Isi hanya untuk menggantinya; pengguna wajib menggantinya lagi saat login.',
                helperMaxLines: 3,
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
                  selectedColor: AppColors.primaryContainer,
                );
              }).toList(),
            ),

            if (_isOwner) ...[
              const Divider(height: 32),
              const Text(
                'Upah',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              WageEditor(draft: _wage, role: widget.worker['role'].toString()),
            ],

            if (_isMandor) ...[
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
                backgroundColor: AppColors.primary,
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
