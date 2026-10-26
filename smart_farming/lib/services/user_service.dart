import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  final String baseUrl = 'http://192.168.1.5:8000/api';

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/user'),
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
}