import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'attendance_history_screen.dart';
import 'scanner_screen.dart';

/// Today's attendance: when the employee checked in, the hours so far, and the button to scan the QR code.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  MeInfo? _me;
  String? _error;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // The hours of today keep counting while the employee is on duty.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _me?.today.onDuty == true) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await FieldService.me();
    if (!mounted) return;
    setState(() {
      _me = result.me;
      _error = result.error;
      _loading = false;
    });
  }

  Future<void> _scan() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = _me?.today;
    final checkedIn = today?.checkedIn ?? false;
    final onDuty = today?.onDuty ?? false;
    final title = !checkedIn
        ? 'You are not checked in'
        : (onDuty ? 'You are checked in' : 'You are checked out');
    final stamp = onDuty || checkedIn ? clockTime(today?.checkInTime) : '';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorNotice(message: _error!, onRetry: _load)
          else ...[
            Center(
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySoft,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 8),
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 70,
                  color: checkedIn ? AppColors.primary : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w800),
            ),
            if (stamp.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                stamp,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.primary, fontSize: 30, fontWeight: FontWeight.w900),
              ),
              Text(
                shortDate(DateTime.now().toIso8601String()),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.timer_outlined,
                    label: "Today's Hours",
                    value: checkedIn ? today!.hoursLabel(DateTime.now()) : '0h 0m',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.circle,
                    iconSize: 12,
                    label: 'Status',
                    value: onDuty ? 'On Duty' : (checkedIn ? 'Off Duty' : 'Not in'),
                    valueColor: onDuty ? AppColors.success : AppColors.muted,
                  ),
                ),
              ],
            ),
            if (today != null && today.overtimeIn != null) ...[
              const SizedBox(height: 12),
              _InfoTile(
                icon: Icons.more_time,
                label: today.overtimeRunning ? 'Overtime (running)' : 'Overtime',
                value: today.overtimeRunning
                    ? 'Since ${clockTime(today.overtimeIn)} · ${today.overtimeLabel}'
                    : '${clockTime(today.overtimeIn)} – ${clockTime(today.overtimeOut)} · ${today.overtimeLabel}',
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: today?.overtimeRunning == true ? 'End Overtime' : (onDuty ? 'Check Out' : 'Check In'),
              icon: Icons.qr_code_scanner,
              onPressed: _scan,
            ),
            const SizedBox(height: 10),
            const Text(
              'Scan the QR code of your branch. The first scan is the time in, the next one the time out. For overtime, scan the overtime QR code: the first scan starts it, the next one ends it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Attendance history'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.iconSize = 18,
    this.valueColor = AppColors.text,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: iconSize, color: valueColor == AppColors.text ? AppColors.primary : valueColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}
