import '../models/models.dart';
import 'api_client.dart';

class AttendanceService {
  /// Records a scan of the attendance QR code (the first scan is the time in, the next one the time out).
  static Future<Map<String, dynamic>> scanQR(String qrCode) =>
      ApiClient.post('scan_attendance.php', {'qr_code': qrCode});

  /// The last days of attendance of the signed-in employee, with the totals of those days.
  static Future<({List<AttendanceDay> days, AttendanceSummary summary, String? error})> history() async {
    final result = await ApiClient.get('attendance_history.php');
    if (result['success'] != true) {
      return (days: <AttendanceDay>[], summary: const AttendanceSummary(), error: result['message']?.toString());
    }
    final rows = result['data'];
    final days = rows is List
        ? rows
            .whereType<Map>()
            .map((row) => AttendanceDay.fromJson(Map<String, dynamic>.from(row)))
            .toList()
        : <AttendanceDay>[];
    final summary = result['summary'];
    return (
      days: days,
      summary: summary is Map ? AttendanceSummary.fromJson(Map<String, dynamic>.from(summary)) : const AttendanceSummary(),
      error: null,
    );
  }
}
