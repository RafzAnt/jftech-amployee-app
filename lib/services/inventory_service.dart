import '../models/models.dart';
import 'api_client.dart';

class InventoryService {
  /// The stock of the employee's branch. [available] can be requested (item out); [all] can be returned.
  static Future<({List<StockItem> available, List<StockItem> all, String? error})> items() async {
    final result = await ApiClient.get('inventory_items.php');
    if (result['success'] != true) {
      return (available: <StockItem>[], all: <StockItem>[], error: result['message']?.toString());
    }
    List<StockItem> parse(dynamic rows) => rows is List
        ? rows
            .whereType<Map>()
            .map((row) => StockItem.fromJson(Map<String, dynamic>.from(row)))
            .toList()
        : <StockItem>[];
    return (available: parse(result['data']), all: parse(result['all_items']), error: null);
  }

  /// Takes an item out of stock (type 'out') or brings it back (type 'return'). The admin approves it.
  static Future<Map<String, dynamic>> submit({
    required String type,
    required int inventoryId,
    required int quantity,
    required String condition,
    String areaUsed = '',
    String personInCharge = '',
    String comments = '',
  }) =>
      ApiClient.post('inventory_request_create.php', {
        'request_type': type,
        'items': [
          {'inventory_id': inventoryId, 'quantity': quantity, 'comments': comments},
        ],
        'item_condition': condition,
        'area_used': areaUsed,
        'person_in_charge': personInCharge,
      });
}
