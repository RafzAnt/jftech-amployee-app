import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'work_request_detail_screen.dart';

/// Everything the employee did: items out and back, installations and repairs.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _type = 'all';
  List<TransactionEntry> _entries = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await FieldService.transactions(type: _type);
    if (!mounted) return;
    setState(() {
      _entries = result.entries;
      _error = result.error;
      _loading = false;
    });
  }

  void _setType(String type) {
    setState(() {
      _type = type;
      _loading = true;
    });
    _load();
  }

  IconData _icon(String kind) {
    switch (kind) {
      case 'item_out':
        return Icons.north_east;
      case 'item_return':
        return Icons.south_west;
      case 'installation':
        return Icons.cable;
      default:
        return Icons.build_outlined;
    }
  }

  Color _color(String kind) {
    switch (kind) {
      case 'item_out':
        return AppColors.warning;
      case 'item_return':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const {
                  'all': 'All',
                  'inventory': 'Inventory',
                  'installation': 'Installation',
                  'repair': 'Repair',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _type == entry.key,
                      onSelected: (_) => _setType(entry.key),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.border),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _type == entry.key ? Colors.white : AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            ErrorNotice(message: _error!, onRetry: _load)
          else if (_entries.isEmpty)
            const EmptyState(icon: Icons.history, message: 'Nothing here yet.')
          else
            for (final entry in _entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  onTap: entry.kind == 'installation' || entry.kind == 'repair'
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => WorkRequestDetailScreen(requestId: entry.id)),
                          );
                          _load();
                        }
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _color(entry.kind).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon(entry.kind), color: _color(entry.kind)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(entry.title, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                                ),
                                StatusChip.forStatus(entry.status, entry.statusLabel),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(entry.subtitle, style: const TextStyle(color: AppColors.text, fontSize: 14)),
                            if (entry.detail.isNotEmpty)
                              Text(entry.detail, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '${shortDate(entry.occurredAt)}  ${shortTime(entry.occurredAt)}',
                              style: const TextStyle(color: AppColors.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
