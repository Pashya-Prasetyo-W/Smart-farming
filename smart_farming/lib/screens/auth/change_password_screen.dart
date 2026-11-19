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
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: obscure ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
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
              _passwordField(
                controller: _currentController,
                label: 'Password Saat Ini',
                obscure: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 12),
              _passwordField(
                controller: _newController,
                label: 'Password Baru (min. 8 karakter)',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 12),
              _passwordField(
                controller: _confirmController,
                label: 'Ulangi Password Baru',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
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
