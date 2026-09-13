import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'auth_service.dart';

class InventoryRequest {
  final int id;
  final String itemName;
  final int quantity;
  final String comments;
  final String status;
  final DateTime createdAt;
  final DateTime? processedAt;

  InventoryRequest({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.comments,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  factory InventoryRequest.fromJson(Map<String, dynamic> json) {
    return InventoryRequest(
      id: json['id'] ?? 0,
      itemName: json['item_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      comments: json['comments'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      processedAt: json['approved_at'] == null
          ? null
          : DateTime.tryParse(json['approved_at'].toString()),
    );
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy hh:mm a').format(createdAt);
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';

  Color get statusColor {
    if (isPending) return const Color(0xFFFFAB00);
    if (isApproved) return const Color(0xFF00E676);
    return const Color(0xFFFF1744);
  }

  String get statusLabel {
    return status.toUpperCase();
  }

  String get statusMessage {
    if (isApproved) return 'Approved — item will be released to you.';
    if (isDenied) return 'Denied — please contact the administrator if needed.';
    return 'Waiting for administrator approval.';
  }
}

class InventoryItem {
  final int id;
  final String name;
  final String category;
  final int availableQuantity;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.availableQuantity,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: int.tryParse(json['id'].toString()) ?? 0,
    name: json['item_name']?.toString() ?? '',
    category: json['category']?.toString() ?? 'Other',
    availableQuantity: int.tryParse(json['quantity'].toString()) ?? 0,
  );
}

class InventoryService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<Map<String, dynamic>> getAvailableItems() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventory_items.php'),
      );
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final items = (data['data'] as List)
            .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
        return {'success': true, 'data': items};
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createRequest(
    List<InventoryRequestItem> items, {
    String comments = '',
  }) async {
    try {
      final userData = await AuthService.getUserData();
      final employeeId = userData['employeeId'];

      if (employeeId == null) {
        return {
          'success': false,
          'message': 'Employee data not found. Please login again.',
        };
      }

      final itemsJson = items
          .where((item) => item.itemName.isNotEmpty && item.quantity > 0)
          .map(
            (item) => {
              'item_name': item.itemName,
              'inventory_id': item.inventoryId,
              'quantity': item.quantity,
              'comments': comments,
            },
          )
          .toList();

      if (itemsJson.isEmpty) {
        return {
          'success': false,
          'message': 'Please select at least one item with quantity',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/inventory_request_create.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'employee_id': employeeId, 'items': itemsJson}),
      );

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } on FormatException catch (_) {
          return {
            'success': false,
            'message': 'Invalid response format from server.',
          };
        }
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMyRequests() async {
    try {
      final userData = await AuthService.getUserData();
      final employeeId = userData['employeeId'];

      if (employeeId == null) {
        return {'success': false, 'message': 'Employee data not found'};
      }

      final response = await http.get(
        Uri.parse(
          '$baseUrl/inventory_requests_list.php?employee_id=$employeeId',
        ),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] && data['data'] != null) {
            final requests = (data['data'] as List)
                .map((item) => InventoryRequest.fromJson(item))
                .toList();
            return {'success': true, 'data': requests};
          }
          return data;
        } on FormatException catch (_) {
          return {
            'success': false,
            'message': 'Invalid response format from server.',
          };
        }
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}

class InventoryRequestItem {
  final int inventoryId;
  final String itemName;
  final String category;
  int quantity;
  int availableQuantity;

  InventoryRequestItem({
    required this.inventoryId,
    required this.itemName,
    this.category = 'Other',
    this.quantity = 1,
    required this.availableQuantity,
  });
}
