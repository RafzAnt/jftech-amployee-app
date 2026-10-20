import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// The last days of attendance.
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceDay> _days = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await AttendanceService.history();
    if (!mounted) return;
    setState(() {
      _days = result.days;
      _error = result.error;
      _loading = false;
    });
  }

  String _range(String? timeIn, String? timeOut) {
    if (timeIn == null) return '—';
    final start = clockTime(timeIn);
    return timeOut == null ? '$start – …' : '$start – ${clockTime(timeOut)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorNotice(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _days.isEmpty
                      ? ListView(children: const [EmptyState(icon: Icons.event_busy_outlined, message: 'No attendance recorded yet.')])
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _days.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final day = _days[index];
                            return AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          shortDate(day.date),
                                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      if (day.totalHours != null)
                                        Text(
                                          '${day.totalHours!.toStringAsFixed(1)} h',
                                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _SessionRow(label: 'Morning', range: _range(day.morningIn, day.morningOut), status: day.statusMorning),
                                  const SizedBox(height: 6),
                                  _SessionRow(label: 'Afternoon', range: _range(day.afternoonIn, day.afternoonOut), status: day.statusAfternoon),
                                  if (day.overtimeIn != null) ...[
                                    const SizedBox(height: 6),
                                    _SessionRow(
                                      label: 'Overtime',
                                      range: day.overtimeOut == null
                                          ? _range(day.overtimeIn, null)
                                          : '${_range(day.overtimeIn, day.overtimeOut)} (${day.overtimeMinutes ~/ 60}h ${day.overtimeMinutes % 60}m)',
                                      status: '',
                                    ),
                                  ],
                                  if (day.branch.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Branch: ${day.branch}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final String label;
  final String range;
  final String status;

  const _SessionRow({required this.label, required this.range, required this.status});

  @override
  Widget build(BuildContext context) {
    final StatusChip? chip;
    switch (status) {
      case 'present':
        chip = const StatusChip(text: 'Present', color: AppColors.success, background: AppColors.successSoft);
      case 'late':
        chip = const StatusChip(text: 'Late', color: AppColors.warning, background: AppColors.warningSoft);
      case 'absent':
        chip = const StatusChip(text: 'Absent', color: AppColors.danger, background: AppColors.dangerSoft);
      default:
        chip = null;
    }
    return Row(
      children: [
        SizedBox(width: 78, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
        Expanded(child: Text(range, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600))),
        ?chip,
      ],
    );
  }
}
