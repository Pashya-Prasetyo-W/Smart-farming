import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_farming/config/api_config.dart';

class ApiClient {
  static String _errorMessage(Map<String, dynamic> body, String fallback) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return body['message']?.toString() ?? fallback;
  }

  static String query(Map<String, String?> params) {
    final filled = params.entries.where(
      (e) => e.value != null && e.value!.isNotEmpty,
    );
    if (filled.isEmpty) return '';
    return '?${filled.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value!)}').join('&')}';
  }

  static Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final http.Response response;
      if (method == 'GET') {
        response = await http.get(uri, headers: headers);
      } else {
        response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        );
      }

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': map['message']?.toString() ?? '',
          'data': map['data'],
        };
      }

      return {
        'success': false,
        'message': _errorMessage(
          map,
          'Permintaan gagal (${response.statusCode}).',
        ),
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke server.',
        'data': null,
      };
    }
  }
}
