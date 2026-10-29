import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FailureLogService {
  final String baseUrl = 'http://192.168.1.5:8000/api';
  Future<List<dynamic>?> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('$baseUrl/failure-logs'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) return jsonDecode(response.body)['data'];
      return null;
    } catch (e) {
      return null;
    }
  }
}
