import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/transaction_card.dart';

/// Everything the employee did: items out and back, and the installation reports.
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
                  'installation': 'Installations',
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
                child: TransactionCard(entry: entry),
              ),
        ],
      ),
    );
  }
}
