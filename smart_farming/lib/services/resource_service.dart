import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ResourceService {
  final String baseUrl = 'http://192.168.1.5:8000/api';

  Future<List<dynamic>?> getResources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('$baseUrl/resources'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> createResource(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.post(
        Uri.parse('$baseUrl/resources'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateResource(int id, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.put(
        Uri.parse('$baseUrl/resources/$id'),
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

  Future<bool> deleteResource(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.delete(
        Uri.parse('$baseUrl/resources/$id'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
