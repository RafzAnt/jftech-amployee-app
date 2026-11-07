import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/scan_line.dart';

/// Scans the attendance QR code of the branch. The first scan of a session is the time in, the next one the time out.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  String _branch = '';
  bool _isScanning = true;
  bool _processing = false;
  bool _checkingCameraPermission = true;
  bool _cameraPermissionGranted = false;
  String? _lastResult;
  DateTime? _lastScanTime;
  // The line that sweeps up and down the frame while the camera looks for a code.
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
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
    _sweep.repeat(reverse: true);
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
    _sweep.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await AuthService.getUserData();
    if (!mounted) return;
    setState(() => _branch = userData['branch']?.toString() ?? '');
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
    final isSuccess = result['success'] == true;
    final message = result['message']?.toString() ?? 'Unknown response';
    final scanType = result['scan_type']?.toString() ?? '';
    final timeRecorded = result['time']?.toString() ?? '';
    final branch = result['branch_name']?.toString().trim() ?? _branch;
    if (isSuccess && branch.isNotEmpty && branch != _branch) {
      // The server is the source of truth for the employee's branch.
      AuthService.saveBranch(branch);
      setState(() => _branch = branch);
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          size: 48,
          color: isSuccess ? AppColors.success : AppColors.danger,
        ),
        title: Text(isSuccess ? (scanType.isEmpty ? 'Scan recorded' : scanType) : 'Scan failed', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (isSuccess && timeRecorded.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                timeRecorded,
                style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
            if (isSuccess && branch.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Branch: $branch', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          if (!isSuccess)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _resumeScanning();
              },
              child: const Text('SCAN AGAIN'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (mounted) Navigator.of(context).pop(isSuccess);
            },
            child: Text(isSuccess ? 'DONE' : 'CLOSE'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_checkingCameraPermission) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_cameraPermissionGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text(
                'Camera permission is required',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please grant camera permission in your app settings to use the QR scanner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Open Settings',
                icon: Icons.settings,
                onPressed: () async {
                  await openAppSettings();
                  await _requestCameraPermission();
                },
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          if (_branch.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: StatusChip(text: '$_branch branch', color: AppColors.primary, background: AppColors.primarySoft),
            ),
          _buildScanFrame(),
          const SizedBox(height: 16),
          const Text(
            'Align the QR code within the frame',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          const AppCard(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'First scan = time in, second scan = time out',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanFrame() => SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _scannerController,
                tapToFocus: true,
                placeholderBuilder: (_) => const ColoredBox(color: Color(0xFF0D1B33)),
                errorBuilder: (_, error) => ColoredBox(
                  color: const Color(0xFF0D1B33),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 30),
                        const SizedBox(height: 8),
                        Text(
                          error.errorCode.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
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
            const Positioned(top: 0, left: 0, child: _FrameCorner(top: true, left: true)),
            const Positioned(top: 0, right: 0, child: _FrameCorner(top: true, left: false)),
            const Positioned(bottom: 0, left: 0, child: _FrameCorner(top: false, left: true)),
            const Positioned(bottom: 0, right: 0, child: _FrameCorner(top: false, left: false)),
            // Only while it is really looking: not once a code is found and being checked.
            if (_isScanning && !_processing) ScanLine(animation: _sweep),
            if (_processing)
              const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
          ],
        ),
      );
}

class _FrameCorner extends StatelessWidget {
  final bool top;
  final bool left;

  const _FrameCorner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.primary, width: 4);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: !top ? side : BorderSide.none,
          left: left ? side : BorderSide.none,
          right: !left ? side : BorderSide.none,
        ),
      ),
    );
  }
}
