import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// One line of the employee's history: an item out, an item return or an installation report, with what the admin decided.
class TransactionCard extends StatelessWidget {
  final TransactionEntry entry;

  const TransactionCard({super.key, required this.entry});

  IconData get _icon {
    switch (entry.kind) {
      case 'item_out':
        return Icons.north_east;
      case 'installation':
        return Icons.router_outlined;
      default:
        return Icons.south_west;
    }
  }

  Color get _color {
    switch (entry.kind) {
      case 'item_out':
        return AppColors.warning;
      case 'installation':
        return AppColors.primary;
      default:
        return AppColors.success;
    }
  }

  /// "Approved by Maria Santos · Oct 14 1:18 PM", or empty while the request waits.
  String get _decision {
    if (entry.decidedAt.isEmpty) return '';
    final who = entry.decidedBy.isEmpty ? 'the admin' : entry.decidedBy;
    return '${entry.statusLabel} by $who · ${shortDate(entry.decidedAt)} ${shortTime(entry.decidedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _color),
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
                  'Filed ${shortDate(entry.occurredAt)}  ${shortTime(entry.occurredAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                if (decision.isNotEmpty)
                  Text(decision, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
