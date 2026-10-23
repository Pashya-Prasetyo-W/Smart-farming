import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TaskService {
  final String baseUrl = 'http://127.0.0.1:8000/api';

  Future<List<dynamic>?> getTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/tasks'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

    Future<Map<String, dynamic>?> getTaskDetail(int taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

      Future<bool> cancelTask(int taskId, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/cancel'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      );

      print('CANCEL STATUS: ${response.statusCode}');
      print('CANCEL BODY: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('CANCEL ERROR: $e');
      return false;
    }
  }

    Future<bool> startTask(int taskId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/start'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('START STATUS: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('START ERROR: $e');
      return false;
    }
  }

    Future<bool> submitReport(int taskId, List<Map<String, dynamic>> resources, String notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/report'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          // Kita gunakan URL dummy dulu karena kita belum mengimplementasikan Firebase Storage di Flutter
          'media_urls': ['https://dummy-image.com/bukti_kerja.jpg'], 
          'notes': notes,
          'resources': resources, 
        }),
      );

      print('REPORT STATUS: ${response.statusCode}');
      print('REPORT BODY: ${response.body}');
      
      return response.statusCode == 201;
    } catch (e) {
      print('REPORT ERROR: $e');
      return false;
    }
  }
}