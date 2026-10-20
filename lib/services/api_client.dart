import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Talks to the JFTECH server. Every call carries the sign-in token, and every answer comes back as a map with
/// `success` and, when something went wrong, a `message` that is ready to show to the person.
class ApiClient {
  /// Called when the server says the sign-in is no longer valid (the app then goes back to the login screen).
  static void Function()? onUnauthorized;

  static const Duration _timeout = Duration(seconds: 20);

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? query,
  }) => _send('GET', endpoint, query: query);

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) => _send('POST', endpoint, body: body);

  /// A picture from the server (the photo of a NAP box). Null when there is none or it cannot be loaded.
  static Future<Uint8List?> getBytes(String endpoint, {Map<String, String>? query}) async {
    final token = await AuthService.getToken();
    final hadToken = token != null && token.isNotEmpty;
    try {
      var uri = Uri.parse('${AuthService.baseUrl}/$endpoint');
      if (query != null && query.isNotEmpty) {
        uri = uri.replace(queryParameters: query);
      }
      final response = await http
          .get(uri, headers: {if (hadToken) 'Authorization': 'Bearer $token'})
          .timeout(_timeout);
      if (response.statusCode == 401 && hadToken) {
        final callback = onUnauthorized;
        if (callback != null) callback();
      }
      final isPicture = (response.headers['content-type'] ?? '').startsWith('image/');
      return response.statusCode == 200 && isPicture ? response.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String endpoint, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final token = await AuthService.getToken();
    try {
      var uri = Uri.parse('${AuthService.baseUrl}/$endpoint');
      if (query != null && query.isNotEmpty) {
        uri = uri.replace(queryParameters: query);
      }
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final http.Response response;
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(_timeout);
      } else {
        headers['Content-Type'] = 'application/json';
        response = await http
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(_timeout);
      }
      return _decode(response, hadToken: token != null && token.isNotEmpty);
    } on TimeoutException {
      return _failure(
        'The JFTECH server did not respond. Check your internet connection and try again.',
      );
    } catch (_) {
      return _failure(
        'Cannot reach the JFTECH server. Check your internet connection and the server address in Settings.',
      );
    }
  }

  static Map<String, dynamic> _decode(http.Response response, {required bool hadToken}) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } on FormatException {
      data = null;
    }

    if (response.statusCode == 401 && hadToken) {
      final callback = onUnauthorized;
      if (callback != null) callback();
    }

    if (data == null) {
      final isPage = response.body.contains('<html') || response.body.contains('<!DOCTYPE');
      return _failure(
        isPage
            ? 'The server returned an error page (${response.statusCode}). Please try again later.'
            : 'The server sent an answer the app cannot read.',
      );
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    data['success'] = data['success'] == true || (data['success'] == null && ok);
    if (data['success'] != true && (data['message'] == null || data['message'].toString().isEmpty)) {
      data['message'] = 'Something went wrong (${response.statusCode}).';
    }
    // A failed form check lists what is wrong; show the first thing.
    final errors = data['errors'];
    if (data['success'] != true && errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) data['message'] = first.first.toString();
    }
    return data;
  }

  static Map<String, dynamic> _failure(String message) => {
        'success': false,
        'message': message,
      };
}
