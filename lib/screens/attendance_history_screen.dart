import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// The last days of attendance, with the totals of those days at the top.
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceDay> _days = const [];
  AttendanceSummary _summary = const AttendanceSummary();
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
      _summary = result.summary;
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
                          itemCount: _days.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) return _SummaryCard(summary: _summary);
                            final day = _days[index - 1];
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
                                  if (day.complete || day.lateMinutes > 0 || day.undertimeMinutes > 0 || day.overtimeMinutes > 0) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (day.complete && day.overtimeMinutes == 0)
                                          const StatusChip(text: 'Complete day', color: AppColors.success, background: AppColors.successSoft),
                                        if (day.lateMinutes > 0)
                                          StatusChip(text: 'Late ${durationLabel(day.lateMinutes)}', color: AppColors.warning, background: AppColors.warningSoft),
                                        if (day.undertimeMinutes > 0)
                                          StatusChip(text: 'Undertime ${durationLabel(day.undertimeMinutes)}', color: AppColors.danger, background: AppColors.dangerSoft),
                                        if (day.overtimeMinutes > 0)
                                          day.overtimeMinutes >= _summary.overtimeMinimumMinutes
                                              ? StatusChip(text: 'Overtime ${durationLabel(day.overtimeMinutes)}', color: AppColors.primary, background: AppColors.primarySoft)
                                              : StatusChip(text: 'Overtime ${durationLabel(day.overtimeMinutes)} · not paid', color: AppColors.muted, background: AppColors.primarySoft),
                                      ],
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

/// What the days below add up to: days worked, hours, and the minutes of late, undertime and overtime.
class _SummaryCard extends StatelessWidget {
  final AttendanceSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final days = summary.daysWorked == summary.daysWorked.roundToDouble()
        ? summary.daysWorked.toStringAsFixed(0)
        : summary.daysWorked.toStringAsFixed(1);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 30 days', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              _Figure(label: 'Days worked', value: days),
              _Figure(label: 'Hours', value: summary.totalHours.toStringAsFixed(1)),
              _Figure(label: 'Absent', value: '${summary.absentSessions}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Figure(label: 'Late', value: durationLabel(summary.lateMinutes)),
              _Figure(label: 'Undertime', value: durationLabel(summary.undertimeMinutes)),
              _Figure(label: 'Overtime', value: durationLabel(summary.overtimeMinutes)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;

  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );
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
