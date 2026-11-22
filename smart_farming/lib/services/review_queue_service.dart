import 'attendance_service.dart';
import 'report_review_service.dart';

class ReviewQueueService {
  Future<Map<String, int>> counts() async {
    final results = await Future.wait([
      AttendanceService().queue(),
      ReportReviewService().queue(),
    ]);

    int count(Map<String, dynamic> result) {
      if (result['success'] != true) return 0;
      final data = result['data'];
      return data is List ? data.length : 0;
    }

    return {'attendance': count(results[0]), 'reports': count(results[1])};
  }
}
