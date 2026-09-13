import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  static const _graphite = Color(0xFF14161C);
  static const _card = Color(0xFF1A1C23);
  static const _accent = Color(0xFF4C7EDB);
  static const _muted = Color(0xFF8A8D94);

  String _fullName = '';
  String _position = '';
  bool _isScanning = true;
  bool _processing = false;
  bool _checkingCameraPermission = true;
  bool _cameraPermissionGranted = false;
  String? _lastResult;
  DateTime? _lastScanTime;
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    await _applyCameraPermission(status);
  }

  Future<void> _refreshCameraPermission() async {
    await _applyCameraPermission(await Permission.camera.status);
  }

  Future<void> _applyCameraPermission(PermissionStatus status) async {
    if (!mounted) return;
    setState(() {
      _cameraPermissionGranted = status.isGranted;
      _checkingCameraPermission = false;
    });
    if (status.isGranted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await _scannerController.start();
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _cameraPermissionGranted = false;
            _checkingCameraPermission = false;
          });
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCameraPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await AuthService.getUserData();
    if (!mounted) return;
    setState(() {
      _fullName = userData['fullName'] ?? 'Employee';
      _position = userData['position'] ?? '';
    });
  }

  String get _loggedInAs =>
      _position.trim().isEmpty ? 'Employee' : _position.trim();

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Log out'),
        content: const Text('Do you want to log out from this device?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleScan(String qrCode) async {
    if (_lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!).inSeconds < 5 &&
        _lastResult == qrCode) {
      return;
    }

    setState(() {
      _processing = true;
      _lastResult = qrCode;
      _lastScanTime = DateTime.now();
    });
    // A running camera preview can sit above an overlay on some Android
    // devices. Stop it before opening the result dialog.
    await _scannerController.stop();
    final result = await AttendanceService.scanQR(qrCode);
    if (!mounted) return;
    setState(() => _processing = false);
    _showResultDialog(result);
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final isSuccess = result['success'] ?? false;
    final message = result['message'] ?? 'Unknown response';
    final scanType = result['scan_type'] ?? '';
    final timeRecorded = result['time'] ?? '';
    final position = result['position']?.toString() ?? _position;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          isSuccess ? 'Scan recorded' : 'Scan failed',
          style: const TextStyle(color: _accent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(color: Color(0xFFE6E7EA))),
            if (isSuccess && position.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Position: $position',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          if (scanType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '$scanType · $timeRecorded',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              _resumeScanning();
            },
            child: const Text('SCAN AGAIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _resumeScanning() async {
    if (!mounted) return;
    setState(() => _isScanning = true);
    try {
      await _scannerController.start();
    } catch (_) {
      // The camera permission/error state is already displayed by the scanner.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingCameraPermission) {
      return const Scaffold(
        backgroundColor: _graphite,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    if (!_cameraPermissionGranted) {
      return Scaffold(
        backgroundColor: _graphite,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    size: 64,
                    color: Color(0xFF4C7EDB),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera permission is required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please grant camera permission in your app settings to use the QR scanner.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await openAppSettings();
                      await _requestCameraPermission();
                    },
                    icon: const Icon(Icons.settings, color: Colors.white),
                    label: const Text('Open Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _graphite,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  children: [
                    _buildUserCard(),
                    const SizedBox(height: 38),
                    _buildScanFrame(),
                    const SizedBox(height: 16),
                    const Text(
                      'Align QR code within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    _buildInfoPill(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    height: 58,
    padding: const EdgeInsets.only(left: 20, right: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF22252E))),
    ),
    child: Stack(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'SCAN QR CODE',
            style: TextStyle(
              color: _accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              letterSpacing: 1.1,
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 112),
            child: Text(
              'Logged in as $_loggedInAs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_outlined, color: _muted, size: 21),
          ),
        ),
      ],
    ),
  );

  Widget _buildUserCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF2C2F38)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF23262F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accent),
          ),
          child: Text(
            _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: _accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fullName.isEmpty ? 'Employee' : _fullName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE6E7EA),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('EEE, MMM d, yyyy').format(DateTime.now()),
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent),
          ),
          child: Text(
            DateFormat('hh:mm a').format(DateTime.now()),
            style: const TextStyle(
              color: _accent,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildScanFrame() => SizedBox(
    width: 220,
    height: 220,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: MobileScanner(
            controller: _scannerController,
            tapToFocus: true,
            placeholderBuilder: (_) =>
                const ColoredBox(color: Color(0xFF0D0F14)),
            errorBuilder: (_, error) => ColoredBox(
              color: const Color(0xFF1A1C23),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: _accent,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.errorCode.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            onDetect: (capture) {
              if (!_isScanning || _processing) return;
              for (final barcode in capture.barcodes) {
                final code = barcode.rawValue;
                if (code != null) {
                  setState(() => _isScanning = false);
                  _handleScan(code);
                  break;
                }
              }
            },
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          child: _FrameCorner(top: true, left: true),
        ),
        const Positioned(
          top: 0,
          right: 0,
          child: _FrameCorner(top: true, left: false),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          child: _FrameCorner(top: false, left: true),
        ),
        const Positioned(
          bottom: 0,
          right: 0,
          child: _FrameCorner(top: false, left: false),
        ),
        if (_processing)
          const Center(
            child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
          ),
      ],
    ),
  );

  Widget _buildInfoPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF2C2F38)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, size: 15, color: _accent),
        SizedBox(width: 7),
        Text(
          'First scan = time in, second scan = time out',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _FrameCorner extends StatelessWidget {
  final bool top;
  final bool left;

  const _FrameCorner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      border: Border(
        top: top
            ? const BorderSide(color: Color(0xFF4C7EDB), width: 2)
            : BorderSide.none,
        bottom: !top
            ? const BorderSide(color: Color(0xFF4C7EDB), width: 2)
            : BorderSide.none,
        left: left
            ? const BorderSide(color: Color(0xFF4C7EDB), width: 2)
            : BorderSide.none,
        right: !left
            ? const BorderSide(color: Color(0xFF4C7EDB), width: 2)
            : BorderSide.none,
      ),
    ),
  );
}
