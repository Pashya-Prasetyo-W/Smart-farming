import 'api_client.dart';

class InventoryService {
  Future<Map<String, dynamic>> purchases({String? status}) => ApiClient.send(
    'GET',
    '/resource-purchases${ApiClient.query({'status': status})}',
  );

  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> body) =>
      ApiClient.send('POST', '/resource-purchases', body: body);

  Future<Map<String, dynamic>> approvePurchase(int id) =>
      ApiClient.send('POST', '/resource-purchases/$id/approve');

  Future<Map<String, dynamic>> rejectPurchase(int id, String reason) =>
      ApiClient.send(
        'POST',
        '/resource-purchases/$id/reject',
        body: {'reason': reason},
      );

  Future<Map<String, dynamic>> cancelPurchase(int id) =>
      ApiClient.send('POST', '/resource-purchases/$id/cancel');

  Future<Map<String, dynamic>> incidents({String? status}) => ApiClient.send(
    'GET',
    '/tool-incidents${ApiClient.query({'status': status})}',
  );

  Future<Map<String, dynamic>> createIncident(Map<String, dynamic> body) =>
      ApiClient.send('POST', '/tool-incidents', body: body);

  Future<Map<String, dynamic>> resolveIncident(
    int id,
    Map<String, dynamic> body,
  ) => ApiClient.send('POST', '/tool-incidents/$id/resolve', body: body);
}
