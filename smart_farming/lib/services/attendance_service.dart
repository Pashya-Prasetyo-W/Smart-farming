import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_farming/config/api_config.dart';

class AttendanceService {
  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _errorMessage(Map<String, dynamic> body, String fallback) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return body['message']?.toString() ?? fallback;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = await _headers();

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
        'message': _errorMessage(map, 'Permintaan gagal (${response.statusCode}).'),
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

  String _query(Map<String, String?> params) {
    final filled = params.entries.where((e) => e.value != null && e.value!.isNotEmpty);
    if (filled.isEmpty) return '';
    return '?${filled.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value!)}').join('&')}';
  }

  Future<Map<String, dynamic>> today() => _send('GET', '/attendances/today');

  Future<Map<String, dynamic>> checkIn() => _send('POST', '/attendances/check-in');

  Future<Map<String, dynamic>> checkOut() => _send('POST', '/attendances/check-out');

  Future<Map<String, dynamic>> mine({String? from, String? to}) =>
      _send('GET', '/attendances/mine${_query({'from': from, 'to': to})}');

  Future<Map<String, dynamic>> history({
    String? from,
    String? to,
    String? status,
    int? userId,
  }) =>
      _send(
        'GET',
        '/attendances${_query({
          'from': from,
          'to': to,
          'status': status,
          'user_id': userId?.toString(),
        })}',
      );

  Future<Map<String, dynamic>> queue() => _send('GET', '/attendances/queue');

  Future<Map<String, dynamic>> verify(int id) =>
      _send('POST', '/attendances/$id/verify');

  Future<Map<String, dynamic>> reject(int id, String reason) =>
      _send('POST', '/attendances/$id/reject', body: {'reason': reason});

  Future<Map<String, dynamic>> object(int id, String note) =>
      _send('POST', '/attendances/$id/object', body: {'note': note});

  Future<Map<String, dynamic>> record({
    required int userId,
    required String workDate,
    required String checkInTime,
    String? checkOutTime,
  }) =>
      _send('POST', '/attendances', body: {
        'user_id': userId,
        'work_date': workDate,
        if (checkOutTime != null) 'check_out_time': checkOutTime,
        'check_in_time': checkInTime,
      });
}
