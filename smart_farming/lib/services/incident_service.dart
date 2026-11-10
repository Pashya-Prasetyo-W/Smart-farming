import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_farming/config/api_config.dart';

class IncidentService {
  Future<bool> createIncident({
    required int landId,
    required String type,
    required String description,
    required File imageFile,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/upload'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var streamedResponse = await request.send();
      var uploadResponse = await http.Response.fromStream(streamedResponse);

      if (uploadResponse.statusCode != 200) {
        return false;
      }

      final mediaUrl = jsonDecode(uploadResponse.body)['url'];

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/incidents'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'land_id': landId,
          'type': type,
          'description': description,
          'media_urls': [mediaUrl],
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>?> getIncidents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/incidents'),
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
