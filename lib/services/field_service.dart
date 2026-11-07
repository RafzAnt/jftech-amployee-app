import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';

/// Home screen, NAP boxes and the transaction history.
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

  // ---- history --------------------------------------------------------------------------------

  static Future<({List<TransactionEntry> entries, String? error})> transactions({String type = 'all'}) async {
    final result = await ApiClient.get('transactions.php', query: {'type': type});
    if (result['success'] != true) return (entries: <TransactionEntry>[], error: result['message']?.toString());
    return (entries: _rows(result['data']).map(TransactionEntry.fromJson).toList(), error: null);
  }
}
