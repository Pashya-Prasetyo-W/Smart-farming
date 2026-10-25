import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

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

    Future<bool> updateTask(int taskId, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitReportWithUrl(int taskId, List<Map<String, dynamic>> resources, String notes, String mediaUrl) async {
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
        'media_urls': [mediaUrl],
        'notes': notes,
        'resources': resources,
      }),
    );
    return response.statusCode == 201;
  } catch (e) {
    return false;
  }
}

  Future<bool> createTask(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      print('CREATE TASK STATUS: ${response.statusCode}');
      print('CREATE TASK BODY: ${response.body}');
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadFile(File file) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url']; // Mengembalikan URL dari Laravel
      }
      return null;
    } catch (e) {
      print('UPLOAD ERROR: $e');
      return null;
    }
  }
}
