import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';

/// Home screen, NAP boxes, clients, installation and repair requests and the transaction history.
class FieldService {
  static List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<({MeInfo? me, String? error})> me() async {
    final result = await ApiClient.get('me.php');
    if (result['success'] != true) return (me: null, error: result['message']?.toString());
    return (me: MeInfo.fromJson(result), error: null);
  }

  static Future<List<String>> barangays() async {
    final result = await ApiClient.get('barangays.php');
    final data = result['data'];
    return data is List ? data.map((item) => item.toString()).toList() : <String>[];
  }

  static Future<List<ClientSummary>> searchClients(String query, {String barangay = ''}) async {
    final result = await ApiClient.get('clients_search.php', query: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (barangay.isNotEmpty) 'barangay': barangay,
    });
    return _rows(result['data']).map(ClientSummary.fromJson).toList();
  }

  // ---- NAP boxes ------------------------------------------------------------------------------

  static Future<({List<NapBox> boxes, String? error})> napBoxes({
    String barangay = '',
    String search = '',
    String filter = 'all',
  }) async {
    final result = await ApiClient.get('nap_boxes.php', query: {
      if (barangay.isNotEmpty) 'barangay': barangay,
      if (search.trim().isNotEmpty) 'q': search.trim(),
      'filter': filter,
    });
    if (result['success'] != true) return (boxes: <NapBox>[], error: result['message']?.toString());
    return (boxes: _rows(result['data']).map(NapBox.fromJson).toList(), error: null);
  }

  static Future<({NapBox? box, String? error})> napBox(int id) async {
    final result = await ApiClient.get('nap_box.php', query: {'nap_box_id': '$id'});
    if (result['success'] != true || result['data'] is! Map) {
      return (box: null, error: result['message']?.toString() ?? 'That NAP box was not found.');
    }
    return (box: NapBox.fromJson(Map<String, dynamic>.from(result['data'] as Map)), error: null);
  }

  /// The photo of a NAP box, or null when it has none. [version] changes when the photo does.
  static Future<Uint8List?> napBoxPhoto(int id, {String? version}) =>
      ApiClient.getBytes('nap_box_photo.php', query: {'nap_box_id': '$id', 'v': ?version});

  // ---- work requests --------------------------------------------------------------------------

  static Future<({List<WorkRequest> requests, String? error})> workRequests({String status = ''}) async {
    final result = await ApiClient.get('work_requests.php', query: {if (status.isNotEmpty) 'status': status});
    if (result['success'] != true) return (requests: <WorkRequest>[], error: result['message']?.toString());
    return (requests: _rows(result['data']).map(WorkRequest.fromJson).toList(), error: null);
  }

  static Future<({WorkRequest? request, String? error})> workRequest(int id) async {
    final result = await ApiClient.get('work_request.php', query: {'id': '$id'});
    if (result['success'] != true || result['data'] is! Map) {
      return (request: null, error: result['message']?.toString() ?? 'That request was not found.');
    }
    return (request: WorkRequest.fromJson(Map<String, dynamic>.from(result['data'] as Map)), error: null);
  }

  /// Sends a new request, or the corrected one when [requestId] is given.
  static Future<Map<String, dynamic>> submitWorkRequest(Map<String, dynamic> form, {int? requestId}) {
    if (requestId == null) return ApiClient.post('work_request_create.php', form);
    return ApiClient.post('work_request_update.php', {...form, 'id': requestId});
  }

  static Future<Map<String, dynamic>> cancelWorkRequest(int id) =>
      ApiClient.post('work_request_cancel.php', {'id': id});

  static Future<Map<String, dynamic>> completeWorkRequest(int id, Map<String, dynamic> report) =>
      ApiClient.post('work_request_complete.php', {...report, 'id': id});

  // ---- history --------------------------------------------------------------------------------

  static Future<({List<TransactionEntry> entries, String? error})> transactions({String type = 'all'}) async {
    final result = await ApiClient.get('transactions.php', query: {'type': type});
    if (result['success'] != true) return (entries: <TransactionEntry>[], error: result['message']?.toString());
    return (entries: _rows(result['data']).map(TransactionEntry.fromJson).toList(), error: null);
  }
}
