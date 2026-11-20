import 'api_client.dart';

class PayrollService {
  Future<Map<String, dynamic>> list() => ApiClient.send('GET', '/payrolls');

  Future<Map<String, dynamic>> create(String start, String end) =>
      ApiClient.send(
        'POST',
        '/payrolls',
        body: {'period_start': start, 'period_end': end},
      );

  Future<Map<String, dynamic>> detail(int id) =>
      ApiClient.send('GET', '/payrolls/$id');

  Future<Map<String, dynamic>> recalculate(int id) =>
      ApiClient.send('POST', '/payrolls/$id/recalculate');

  Future<Map<String, dynamic>> approve(int id) =>
      ApiClient.send('POST', '/payrolls/$id/approve');

  Future<Map<String, dynamic>> pay(int id) =>
      ApiClient.send('POST', '/payrolls/$id/pay');

  Future<Map<String, dynamic>> remove(int id) =>
      ApiClient.send('DELETE', '/payrolls/$id');

  Future<Map<String, dynamic>> mine() =>
      ApiClient.send('GET', '/payrolls/mine');
}
