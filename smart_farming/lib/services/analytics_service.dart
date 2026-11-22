import 'api_client.dart';

class AnalyticsService {
  Future<Map<String, dynamic>> profit({String? status}) => ApiClient.send(
    'GET',
    '/analytics/profit${ApiClient.query({'status': status})}',
  );

  Future<Map<String, dynamic>> risk() =>
      ApiClient.send('GET', '/analytics/risk');
}
