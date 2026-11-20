import 'api_client.dart';

class ReportReviewService {
  Future<Map<String, dynamic>> queue() =>
      ApiClient.send('GET', '/task-reports/queue');

  Future<Map<String, dynamic>> history({String? status}) =>
      ApiClient.send('GET', '/task-reports${ApiClient.query({'status': status})}');

  Future<Map<String, dynamic>> verify(int id) =>
      ApiClient.send('POST', '/task-reports/$id/verify');

  Future<Map<String, dynamic>> reject(int id, String reason) =>
      ApiClient.send('POST', '/task-reports/$id/reject', body: {'reason': reason});

  Future<Map<String, dynamic>> object(int id, String note) =>
      ApiClient.send('POST', '/task-reports/$id/object', body: {'note': note});
}
