import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/attendance_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _graphite = Color(0xFF14161C);
  static const _card = Color(0xFF1A1C23);
  static const _border = Color(0xFF2C2F38);
  static const _accent = Color(0xFF4C7EDB);
  static const _muted = Color(0xFF8A8D94);

  List<dynamic> _attendanceHistory = [];
  final Set<String> _expandedDayIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await AttendanceService.getAttendanceHistory();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _attendanceHistory = result['data'] ?? [];
      } else {
        _error = result['message'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _graphite,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
        height: 58,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF22252E))),
        ),
        child: Row(
          children: [
            const SizedBox(width: 48),
            const Expanded(
              child: Text(
                'MY HISTORY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  letterSpacing: 1.1,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_outlined, color: _muted, size: 21),
              onPressed: _loadHistory,
              tooltip: 'Refresh',
            ),
          ],
        ),
      );

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFC95B5B), size: 38),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadHistory, child: const Text('RETRY', style: TextStyle(color: _accent))),
            ],
          ),
        ),
      );
    }
    if (_attendanceHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, color: _accent, size: 42),
            SizedBox(height: 12),
            Text('No attendance records yet', style: TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: _accent,
      backgroundColor: _card,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _attendanceHistory.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _buildDayCard(_attendanceHistory[index], index),
      ),
    );
  }

  Widget _buildDayCard(dynamic record, int index) {
    final date = DateTime.tryParse(record['attendance_date']?.toString() ?? '') ?? DateTime.now();
    final dayId = record['attendance_date']?.toString() ?? index.toString();
    final morningIn = record['morning_time_in']?.toString();
    final morningOut = record['morning_time_out']?.toString();
    final afternoonIn = record['afternoon_time_in']?.toString();
    final afternoonOut = record['afternoon_time_out']?.toString();
    final position = record['position']?.toString() ?? '';
    final isPresent = _hasTime(morningIn) || _hasTime(afternoonIn);
    final statusColor = isPresent ? const Color(0xFF5FAE7A) : const Color(0xFFC95B5B);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (!_expandedDayIds.add(dayId)) _expandedDayIds.remove(dayId);
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.55)),
                ),
                child: Icon(isPresent ? Icons.check : Icons.close, color: statusColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, MMM d, yyyy').format(date), style: const TextStyle(color: Color(0xFFE6E7EA), fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(isPresent ? 'Present' : 'Absent', style: TextStyle(color: statusColor, fontSize: 11)),
                    if (position.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(position, style: const TextStyle(color: _muted, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.55)),
                ),
                child: Text(isPresent ? 'PRESENT' : 'ABSENT', style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              ),
            ],
          ),
          if (_expandedDayIds.contains(dayId)) ...[
            const SizedBox(height: 14),
            _buildSessionCard('Morning session', morningIn, morningOut, const Color(0xFFD5A24C)),
            const SizedBox(height: 10),
            _buildSessionCard('Afternoon session', afternoonIn, afternoonOut, _accent),
          ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(String label, String? timeIn, String? timeOut, Color labelColor) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _graphite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: labelColor, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text(label, style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildTimeBox('Time in', timeIn)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: _muted, size: 15)),
                Expanded(child: _buildTimeBox('Time out', timeOut)),
              ],
            ),
          ],
        ),
      );

  Widget _buildTimeBox(String label, String? time) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
            const SizedBox(height: 3),
            Text(_formatTime(time), style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  bool _hasTime(String? time) => time != null && time.isNotEmpty;

  String _formatTime(String? time) {
    if (!_hasTime(time)) return '--:--';
    final parsed = DateTime.tryParse('2000-01-01 $time');
    return parsed == null ? time! : DateFormat('hh:mm a').format(parsed);
  }
}
