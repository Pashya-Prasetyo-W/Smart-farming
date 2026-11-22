import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_farming/config/api_config.dart';

import 'api_client.dart';

class PlantingService {
  Future<bool> createPlanting(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/plantings'),
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

  Future<List<dynamic>?> getPlantings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/plantings'),
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

  Future<Map<String, dynamic>> summary(int plantingId) =>
      ApiClient.send('GET', '/plantings/$plantingId/summary');

  Future<Map<String, dynamic>> harvests(int plantingId) =>
      ApiClient.send('GET', '/plantings/$plantingId/harvests');

  Future<Map<String, dynamic>> recordHarvest(
    int plantingId, {
    required String harvestDate,
    required double quantityKg,
    double? soldKg,
    double? pricePerKg,
  }) =>
      ApiClient.send('POST', '/plantings/$plantingId/harvests', body: {
        'harvest_date': harvestDate,
        'quantity_kg': quantityKg,
        if (soldKg != null && soldKg > 0) 'sold_kg': soldKg,
        if (pricePerKg != null && pricePerKg > 0) 'price_per_kg': pricePerKg,
      });

  Future<Map<String, dynamic>> deleteHarvest(int harvestId) =>
      ApiClient.send('DELETE', '/harvests/$harvestId');

  Future<Map<String, dynamic>> closePlanting(int plantingId) =>
      ApiClient.send('POST', '/plantings/$plantingId/harvest');

  Future<bool> cancelPlanting(int plantingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/plantings/$plantingId/cancel'),
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
