import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Email wajib diisi.');
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService().forgotPassword(email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) _codeSent = true;
    });
    _showMessage(result['message'].toString());
  }

  Future<void> _resetPassword() async {
    if (_codeController.text.length != 6) {
      _showMessage('Kode terdiri dari 6 digit.');
      return;
    }
    if (_passwordController.text.length < 8) {
      _showMessage('Password baru minimal 8 karakter.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      _showMessage('Konfirmasi password tidak sama.');
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService().resetPassword(
      _emailController.text.trim(),
      _codeController.text.trim(),
      _passwordController.text,
      _confirmController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(result['message'])));
    } else {
      _showMessage(result['message'].toString());
    }
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
        border: const OutlineInputBorder(),
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
        title: const Text(
          'Lupa Password'
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Fitur ini khusus akun Pemilik. Mandor dan buruh yang lupa password perlu meminta atasannya mengatur ulang dari menu Manajemen Karyawan.',
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Pemilik',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (!_codeSent)
              ElevatedButton(
                onPressed: _isLoading ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                    : const Text('KIRIM KODE'),
              )
            else ...[
              const Text(
                'Masukkan kode 6 digit yang dikirim ke email Anda. Kode berlaku 15 menit.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Kode Verifikasi',
                  prefixIcon: Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              _passwordField(
                controller: _passwordController,
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                    : const Text('ATUR ULANG PASSWORD'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : _sendCode,
                child: const Text('Kirim ulang kode'),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _codeController.clear();
                      }),
                child: const Text('Ganti email'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
