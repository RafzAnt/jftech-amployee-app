import '../models/models.dart';
import 'api_client.dart';

/// The installation report: what the form offers, the reports the employee sent, and sending a new one.
class InstallationService {
  static Future<({InstallationOptions? options, String? error})> options() async {
    final result = await ApiClient.get('installation_options.php');
    if (result['success'] != true) return (options: null, error: result['message']?.toString());
    return (options: InstallationOptions.fromJson(result), error: null);
  }

  static Future<({List<InstallationReport> reports, String? error})> reports() async {
    final result = await ApiClient.get('installations.php');
    if (result['success'] != true) return (reports: <InstallationReport>[], error: result['message']?.toString());
    final rows = result['data'];
    final reports = rows is List
        ? rows.whereType<Map>().map((row) => InstallationReport.fromJson(Map<String, dynamic>.from(row))).toList()
        : <InstallationReport>[];
    return (reports: reports, error: null);
  }

  /// Where a barangay of the employee's branch is (its town when the map has no such barangay).
  static Future<({PlaceLocation? place, String? error})> barangayLocation(String barangay) async {
    final result = await ApiClient.get('barangay_location.php', query: {'barangay': barangay});
    if (result['success'] != true) return (place: null, error: result['message']?.toString());
    return (place: PlaceLocation.fromJson(result), error: null);
  }

  /// Sends the report. The admin confirms it before the registered client is activated.
  static Future<Map<String, dynamic>> submit(InstallationDraft draft) => ApiClient.post('installation_create.php', draft.toJson());
}
