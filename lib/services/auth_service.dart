import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const Duration sessionTimeout = Duration(minutes: 15);
  static const _isLoggedInKey = 'isLoggedIn';
  static const _backgroundAtKey = 'backgroundAt';
  static const _baseUrlKey = 'apiBaseUrl';
  static const _pendingLogoutIdsKey = 'pendingLogoutHistoryIds';

  static const _defaultBaseUrl = 'http://localhost:8000/backend/api';
  static String _baseUrl = _defaultBaseUrl;

  static String get baseUrl => _baseUrl;

  static String normalizeUrl(String url) {
    url = url.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    // Laravel's local development server listens on port 8000. A URL such as
    // http://192.168.1.15/backend/api otherwise goes to port 80, which is why
    // it returns a 404 even while `php artisan serve` is running correctly.
    final uri = Uri.tryParse(url);
    if (uri != null &&
        uri.scheme == 'http' &&
        uri.host.isNotEmpty &&
        !uri.hasPort &&
        _isIpv4Address(uri.host)) {
      url = uri.replace(port: 8000).toString();
    }
    return url;
  }

  static bool _isIpv4Address(String host) {
    final parts = host.split('.');
    return parts.length == 4 &&
        parts.every((part) {
          final value = int.tryParse(part);
          return value != null && value >= 0 && value <= 255;
        });
  }

  static String? validateBaseUrl(String url) {
    url = url.trim();
    if (url.isEmpty) return 'URL cannot be empty';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) {
      return 'Invalid URL format. Example: http://192.168.1.10:8000/backend/api';
    }
    if (uri.path != '/backend/api' && uri.path != '/backend/api/') {
      return 'URL should include the /backend/api path. Example: http://192.168.1.10:8000/backend/api';
    }
    return null;
  }

  static Future<void> initBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_baseUrlKey);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = normalizeUrl(saved);
    }
    await _flushPendingLogouts(prefs);
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = normalizeUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _flushPendingLogouts(prefs);
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/employee_login.php'),
            body: {'username': username, 'password': password},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            return {
              'success': false,
              'message':
                  'Invalid server response. The login API must return a JSON object.',
            };
          }
          final data = decoded;
          if (data['success'] == true && data['user'] is Map) {
            final user = data['user'] as Map;
            final loginHistoryId = int.tryParse(
              user['login_history_id']?.toString() ?? '',
            );
            await prefs.setBool(_isLoggedInKey, true);
            await prefs.remove(_backgroundAtKey);
            await prefs.setInt(
              'userId',
              int.tryParse(user['id'].toString()) ?? 0,
            );
            await prefs.setString(
              'username',
              user['username']?.toString() ?? '',
            );
            await prefs.setString(
              'fullName',
              user['full_name']?.toString() ?? '',
            );
            final assignedPosition =
                user['position'] ??
                user['employee_position'] ??
                data['position'];
            await prefs.setString(
              'position',
              assignedPosition?.toString().trim() ?? '',
            );
            await prefs.setInt(
              'employeeId',
              int.tryParse(user['employee_id'].toString()) ?? 0,
            );
            if (loginHistoryId != null && loginHistoryId > 0) {
              await prefs.setInt('login_history_id', loginHistoryId);
            } else {
              // Keep login compatible with a backend that has not yet been
              // updated, without reusing a history ID from an earlier login.
              await prefs.remove('login_history_id');
            }
          }
          return data;
        } on FormatException catch (_) {
          if (response.body.contains('<html') ||
              response.body.contains('<!DOCTYPE')) {
            if (response.body.contains('sql310.infinityfree.com') ||
                response.body.contains('php_network_getaddresses')) {
              return {
                'success': false,
                'message':
                    'Database connection error: Your PHP backend cannot connect to the MySQL database. Please check your database credentials in the PHP files and ensure the database server is accessible.',
              };
            }
            if (response.body.contains('aes.js') ||
                response.body.contains('__test') ||
                response.body.contains('slowAES')) {
              return {
                'success': false,
                'message':
                    'InfinityFree anti-bot challenge detected. Flutter mobile apps cannot bypass this JavaScript check. Please upgrade to InfinityFree Premium hosting or deploy your backend to a host that allows non-browser API access.',
              };
            }
            return {
              'success': false,
              'message':
                  'Server returned an error page instead of JSON. Check your PHP backend logs for issues.',
            };
          }
          return {
            'success': false,
            'message':
                'Invalid response format from server. Verify that the deployed API URL returns JSON.',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}: ${response.body}',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'The JFTECH server did not respond. Check that the deployed domain, SSL certificate, and PHP API are online.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Cannot reach the JFTECH server at $baseUrl. Check the deployed API URL and internet connection.',
      };
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> markAppInBackground() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_isLoggedInKey) ?? false) {
      await prefs.setInt(
        _backgroundAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  static Future<bool> hasSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_isLoggedInKey) ?? false)) return false;

    final backgroundAt = prefs.getInt(_backgroundAtKey);
    if (backgroundAt == null) return false;
    return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(backgroundAt),
        ) >=
        sessionTimeout;
  }

  static Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getInt('userId'),
      'username': prefs.getString('username'),
      'fullName': prefs.getString('fullName'),
      'position': prefs.getString('position'),
      'employeeId': prefs.getInt('employeeId'),
    };
  }

  static Future<Map<String, dynamic>> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final historyId = prefs.getInt('login_history_id');
    var logoutRecorded = historyId == null || historyId <= 0;

    if (historyId != null && historyId > 0) {
      logoutRecorded = await _recordLogout(historyId);
      if (!logoutRecorded) {
        await _queuePendingLogout(prefs, historyId);
      }
    }

    // Keep the server URL and any queued logout records. Clearing all shared
    // preferences here used to discard an unsent logout time permanently.
    await _clearSession(prefs);
    return {'success': true, 'logoutRecorded': logoutRecorded};
  }

  static Future<bool> _recordLogout(int historyId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/employee_logout.php'),
            body: {'login_history_id': historyId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data is Map && data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _queuePendingLogout(
    SharedPreferences prefs,
    int historyId,
  ) async {
    final ids = _pendingLogoutIds(prefs);
    if (!ids.contains(historyId)) {
      ids.add(historyId);
      await prefs.setString(_pendingLogoutIdsKey, jsonEncode(ids));
    }
  }

  static List<int> _pendingLogoutIds(SharedPreferences prefs) {
    try {
      final value = jsonDecode(prefs.getString(_pendingLogoutIdsKey) ?? '[]');
      if (value is List) {
        return value
            .map((id) => int.tryParse(id.toString()))
            .whereType<int>()
            .where((id) => id > 0)
            .toSet()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _flushPendingLogouts(SharedPreferences prefs) async {
    final remaining = <int>[];
    for (final historyId in _pendingLogoutIds(prefs)) {
      if (!await _recordLogout(historyId)) remaining.add(historyId);
    }

    if (remaining.isEmpty) {
      await prefs.remove(_pendingLogoutIdsKey);
    } else {
      await prefs.setString(_pendingLogoutIdsKey, jsonEncode(remaining));
    }
  }

  static Future<void> _clearSession(SharedPreferences prefs) async {
    await Future.wait([
      prefs.remove(_isLoggedInKey),
      prefs.remove(_backgroundAtKey),
      prefs.remove('userId'),
      prefs.remove('username'),
      prefs.remove('fullName'),
      prefs.remove('position'),
      prefs.remove('employeeId'),
      prefs.remove('login_history_id'),
    ]);
  }
}
