import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth/change_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/mandor/mandor_dashboard_screen.dart';
import '../screens/owner/owner_dashboard_screen.dart';
import '../screens/worker/worker_dashboard_screen.dart';

/// Peran pengguna: pemilik → mandor → buruh.
class RoleRouter {
  /// Layar utama untuk sebuah peran. Peran tak dikenal kembali ke login.
  static Widget dashboardFor(String role) {
    switch (role) {
      case 'pemilik':
        return const OwnerDashboardScreen();
      case 'mandor':
        return const MandorDashboardScreen();
      case 'buruh':
        return const WorkerDashboardScreen();
      default:
        return const LoginScreen();
    }
  }

  /// Layar pertama setelah login / saat aplikasi dibuka kembali.
  /// Akun yang wajib ganti password diarahkan dulu ke layar ganti password.
  static Widget entryFor(String role, {required bool mustChangePassword}) {
    if (mustChangePassword) {
      return ChangePasswordScreen(role: role);
    }
    return dashboardFor(role);
  }

  /// Membaca sesi tersimpan. Mengembalikan null jika belum login.
  static Future<Widget?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    if (token == null || role == null) return null;

    return entryFor(
      role,
      mustChangePassword: prefs.getBool('must_change_password') ?? false,
    );
  }
}
