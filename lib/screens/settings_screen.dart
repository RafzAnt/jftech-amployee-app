import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _graphite = Color(0xFF14161C);
  static const _card = Color(0xFF1A1C23);
  static const _border = Color(0xFF2C2F38);
  static const _accent = Color(0xFF4C7EDB);
  static const _muted = Color(0xFF8A8D94);

  final _urlController = TextEditingController();
  bool _isSaving = false;
  bool _isTesting = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    await AuthService.initBaseUrl();
    if (!mounted) return;
    setState(() => _urlController.text = AuthService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    final url = AuthService.normalizeUrl(_urlController.text);
    final error = AuthService.validateBaseUrl(url);
    if (error != null) {
      setState(() {
        _message = error;
        _isError = true;
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _message = null;
      _isError = false;
    });
    final normalized = AuthService.normalizeUrl(url);
    await AuthService.setBaseUrl(normalized);
    if (!mounted) return;
    setState(() {
      _urlController.text = normalized;
      _isSaving = false;
      _message = 'API URL saved successfully';
      _isError = false;
    });
  }

  Future<void> _useProductionUrl() async {
    setState(() {
      _isSaving = true;
      _message = null;
      _isError = false;
    });
    await AuthService.useProductionUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = AuthService.productionBaseUrl;
      _isSaving = false;
      _message = 'Production server restored. The app will use Vercel by default.';
    });
  }

  Future<void> _testConnection() async {
    final url = AuthService.normalizeUrl(_urlController.text);
    final error = AuthService.validateBaseUrl(url);
    if (error != null) {
      setState(() {
        _message = error;
        _isError = true;
      });
      return;
    }
    setState(() {
      _isTesting = true;
      _message = null;
      _isError = false;
      _urlController.text = url;
    });
    try {
      final response = await http
          .get(Uri.parse('$url/inventory_items.php'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _isTesting = false;
          _message = 'Connected! Server responded with ${response.statusCode}.';
          _isError = false;
        });
      } else {
        setState(() {
          _isTesting = false;
          _message =
              'Server responded with ${response.statusCode}. Check the URL path and backend.';
          _isError = true;
        });
      }
    } on TimeoutException {
      setState(() {
        _isTesting = false;
        _message =
            'Connection timed out. Make sure your phone and the server are on the same Wi-Fi, the backend is running, and the Laravel server was started with --host=0.0.0.0.';
        _isError = true;
      });
    } catch (e) {
      final host = Uri.tryParse(url)?.host ?? 'server';
      setState(() {
        _isTesting = false;
        _message = 'Cannot reach $host. Check that:\n'
            '1. Your phone and laptop are on the same Wi-Fi network\n'
            '2. The backend server is running (php artisan serve --host=0.0.0.0)\n'
            '3. No firewall is blocking port 8000\n'
            '4. The IP address is correct';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _graphite,
      appBar: AppBar(
        backgroundColor: _graphite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE6E7EA)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Color(0xFFE6E7EA), fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE6E7EA),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The deployed Vercel server is the default. Enter a LAN URL only when testing your local server from a phone.',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Testing API URL',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Color(0xFFE6E7EA)),
                      cursorColor: _accent,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.10:8000/backend/api',
                        hintStyle: TextStyle(color: _muted, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF060E1A),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accent, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _useProductionUrl,
                        icon: const Icon(Icons.cloud_done_outlined),
                        label: const Text('USE DEPLOYED VERCEL SERVER'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accent,
                          side: const BorderSide(color: _accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveUrl,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'SAVE',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _isTesting ? null : _testConnection,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _accent,
                                side: const BorderSide(color: _accent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isTesting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _accent,
                                      ),
                                    )
                                  : const Text(
                                      'TEST',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Default: ${AuthService.productionBaseUrl}',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isError
                              ? const Color(0xFFFF1744).withValues(alpha: 0.1)
                              : const Color(0xFF00E676).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isError
                                ? const Color(0xFFFF1744).withValues(alpha: 0.3)
                                : const Color(0xFF00E676).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isError
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: _isError
                                  ? const Color(0xFFFF1744)
                                  : const Color(0xFF00E676),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _message!,
                                style: TextStyle(
                                  color: _isError
                                      ? const Color(0xFFFF1744)
                                      : const Color(0xFF00E676),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current URL',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AuthService.baseUrl,
                      style: const TextStyle(
                        color: Color(0xFFE6E7EA),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}
