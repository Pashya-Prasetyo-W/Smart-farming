import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../utils/role_router.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String role;
  const ChangePasswordScreen({super.key, required this.role});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_currentController.text.isEmpty ||
        _newController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      _showMessage('Semua kolom wajib diisi.');
      return;
    }
    if (_newController.text.length < 8) {
      _showMessage('Password baru minimal 8 karakter.');
      return;
    }
    if (_newController.text != _confirmController.text) {
      _showMessage('Konfirmasi password tidak sama.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService().changePassword(
      _currentController.text,
      _newController.text,
      _confirmController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showMessage('Password berhasil diganti.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RoleRouter.dashboardFor(widget.role),
        ),
      );
    } else {
      _showMessage(result['message'] ?? 'Gagal mengganti password.');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganti Password'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: _logout, child: const Text('Keluar')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Demi keamanan, ganti password sementara Anda sebelum mulai bekerja.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _currentController,
                obscureText: _isObscure,
                decoration: const InputDecoration(
                  labelText: 'Password Saat Ini',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newController,
                obscureText: _isObscure,
                decoration: const InputDecoration(
                  labelText: 'Password Baru (min. 8 karakter)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: 'Ulangi Password Baru',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SIMPAN PASSWORD'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
