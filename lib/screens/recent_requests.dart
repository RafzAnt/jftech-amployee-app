import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/transaction_card.dart';
import 'history_screen.dart';
import 'section_page.dart';

/// The employee's latest item requests under the Item Out / Item Return form: what is waiting for the admin and what was decided.
/// It sits in the list of the Inventory page and loads again when the page does.
class RecentRequests extends StatefulWidget {
  /// Changes when the Inventory page loads again (a request was sent, or the page was pulled to refresh).
  final int refreshToken;

  const RecentRequests({super.key, this.refreshToken = 0});

  @override
  State<RecentRequests> createState() => _RecentRequestsState();
}

class _RecentRequestsState extends State<RecentRequests> {
  static const _shown = 5;

  List<TransactionEntry> _entries = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RecentRequests old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final result = await FieldService.transactions(type: 'inventory');
    if (!mounted) return;
    setState(() {
      _entries = result.entries;
      _error = result.error;
      _loading = false;
    });
  }

  void _openAll() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SectionPage(title: 'Transaction History', child: HistoryScreen())),
      );

  @override
  Widget build(BuildContext context) {
    final waiting = _entries.where((entry) => entry.status == 'pending').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text('My requests', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (waiting > 0)
              StatusChip(text: '$waiting waiting', color: AppColors.warning, background: AppColors.warningSoft),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          ErrorNotice(message: _error!, onRetry: _load)
        else if (_entries.isEmpty)
          const EmptyState(icon: Icons.inbox_outlined, message: 'You have not requested any items yet.')
        else ...[
          for (final entry in _entries.take(_shown))
            Padding(padding: const EdgeInsets.only(bottom: 12), child: TransactionCard(entry: entry)),
          if (_entries.length > _shown)
            TextButton(onPressed: _openAll, child: Text('See all ${_entries.length} requests')),
        ],
      ],
    );
  }
}
