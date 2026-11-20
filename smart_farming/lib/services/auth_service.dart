import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_farming/config/api_config.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['data']['token']);
        await prefs.setString('role', data['data']['user']['role']);
        await prefs.setString('name', data['data']['user']['name']);
        await prefs.setInt('user_id', data['data']['user']['id']);

        final mustChange = data['data']['user']['must_change_password'] == true;
        await prefs.setBool('must_change_password', mustChange);

        return {
          'success': true,
          'role': data['data']['user']['role'],
          'must_change_password': mustChange,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Email atau password salah.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
    String confirmation,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/change-password'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmation,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await prefs.setBool('must_change_password', false);
        return {'success': true};
      }

      String message = data['message'] ?? 'Gagal mengganti password.';
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) message = first.first.toString();
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return _postPublic('/auth/forgot-password', {'email': email});
  }

  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String password,
    String confirmation,
  ) async {
    return _postPublic('/auth/reset-password', {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': confirmation,
    });
  }

  Future<Map<String, dynamic>> _postPublic(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      String message = data['message']?.toString() ?? 'Permintaan gagal.';

      if (response.statusCode != 200) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            message = first.first.toString();
          }
        }
        if (response.statusCode == 429) {
          message = 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
        }
      }

      return {'success': response.statusCode == 200, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String companyName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'company_name': companyName,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registrasi gagal.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server: $e'};
    }
  }
}
