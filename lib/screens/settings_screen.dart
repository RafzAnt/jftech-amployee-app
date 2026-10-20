import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// The address of the JFTECH server. The deployed server is the default; a local one is only for testing.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  void _show(String message, {required bool error}) {
    setState(() {
      _message = message;
      _isError = error;
    });
  }

  Future<void> _saveUrl() async {
    final url = AuthService.normalizeUrl(_urlController.text);
    final error = AuthService.validateBaseUrl(url);
    if (error != null) {
      _show(error, error: true);
      return;
    }
    setState(() {
      _isSaving = true;
      _message = null;
    });
    await AuthService.setBaseUrl(url);
    if (!mounted) return;
    setState(() {
      _urlController.text = AuthService.baseUrl;
      _isSaving = false;
    });
    _show('API URL saved successfully', error: false);
  }

  Future<void> _useProductionUrl() async {
    setState(() {
      _isSaving = true;
      _message = null;
    });
    await AuthService.useProductionUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = AuthService.productionBaseUrl;
      _isSaving = false;
    });
    _show('Production server restored. The app will use Vercel by default.', error: false);
  }

  Future<void> _testConnection() async {
    final url = AuthService.normalizeUrl(_urlController.text);
    final error = AuthService.validateBaseUrl(url);
    if (error != null) {
      _show(error, error: true);
      return;
    }
    setState(() {
      _isTesting = true;
      _message = null;
      _urlController.text = url;
    });
    try {
      // ping.php needs no sign in, so it works before anybody has logged in.
      final response = await http
          .get(Uri.parse('$url/ping.php'), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _isTesting = false);
      if (response.statusCode == 200) {
        _show('Connected! The JFTECH server answered.', error: false);
      } else {
        _show(
          'Server responded with ${response.statusCode}. Check the URL path and that the server is updated.',
          error: true,
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _isTesting = false);
      _show(
        'Connection timed out. Make sure your phone and the server are on the same Wi-Fi, the backend is running, and the Laravel server was started with --host=0.0.0.0.',
        error: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isTesting = false);
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? 'server';
      final port = (uri != null && uri.hasPort) ? uri.port : 8000;
      _show(
        kIsWeb
            ? 'Cannot read the reply from $host. Check that:\n'
                '1. The backend server is running (php artisan serve --host=0.0.0.0 --port=$port)\n'
                '2. The server has the latest update. A web browser only accepts the reply when the server allows it (CORS), and this needs the updated backend\n'
                '3. The URL ends with /backend/api'
            : 'Cannot reach $host. Check that:\n'
                '1. Your phone and laptop are on the same Wi-Fi network\n'
                '2. The backend server is running (php artisan serve --host=0.0.0.0 --port=$port)\n'
                '3. No firewall is blocking port $port\n'
                '4. The IP address is correct',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'The deployed Vercel server is the default. Enter a LAN URL only when testing your local server from a phone.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Testing API URL',
                  style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'http://192.168.1.10:8000/backend/api'),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _useProductionUrl,
                  icon: const Icon(Icons.cloud_done_outlined),
                  label: const Text('Use the deployed Vercel server'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: PrimaryButton(label: 'Save', loading: _isSaving, onPressed: _saveUrl)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isTesting ? null : _testConnection,
                        child: _isTesting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : const Text('Test connection'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Default: ${AuthService.productionBaseUrl}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                if (_message != null)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isError ? AppColors.dangerSoft : AppColors.successSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _isError ? Icons.error_outline : Icons.check_circle_outline,
                          color: _isError ? AppColors.danger : AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _isError ? AppColors.danger : AppColors.success,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current URL',
                  style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  AuthService.baseUrl,
                  style: const TextStyle(color: AppColors.text, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
