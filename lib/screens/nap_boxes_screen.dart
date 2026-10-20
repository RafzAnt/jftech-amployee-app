import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'nap_box_detail_screen.dart';

/// The NAP boxes of the employee's branch: how many ports each has and how many are free.
class NapBoxesScreen extends StatefulWidget {
  const NapBoxesScreen({super.key});

  @override
  State<NapBoxesScreen> createState() => _NapBoxesScreenState();
}

class _NapBoxesScreenState extends State<NapBoxesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _filter = 'all';
  List<NapBox> _boxes = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await FieldService.napBoxes(search: _searchController.text, filter: _filter);
    if (!mounted) return;
    setState(() {
      _boxes = result.boxes;
      _error = result.error;
      _loading = false;
    });
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _setFilter(String filter) {
    setState(() => _filter = filter);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          TextField(
            controller: _searchController,
            onChanged: _searchChanged,
            decoration: const InputDecoration(
              hintText: 'Search NAP box, barangay or location',
              prefixIcon: Icon(Icons.search, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const {'all': 'All', 'available': 'Available', 'full': 'Full'}.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _filter == entry.key,
                  onSelected: (_) => _setFilter(entry.key),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: _filter == entry.key ? Colors.white : AppColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorNotice(message: _error!, onRetry: _load)
          else if (_boxes.isEmpty)
            const EmptyState(icon: Icons.router_outlined, message: 'No NAP boxes found.')
          else
            for (final box in _boxes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NapBoxCard(
                  box: box,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => NapBoxDetailScreen(boxId: box.id, name: box.name)),
                    );
                    _load();
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class _NapBoxCard extends StatelessWidget {
  final NapBox box;
  final VoidCallback onTap;

  const _NapBoxCard({required this.box, required this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: box.isFull ? AppColors.dangerSoft : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.router, color: box.isFull ? AppColors.danger : AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        box.name,
                        style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        text: box.isFull ? 'Full' : '${box.availablePorts} available',
                        color: box.isFull ? AppColors.danger : AppColors.success,
                        background: box.isFull ? AppColors.dangerSoft : AppColors.successSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    box.location.isEmpty ? box.barangay : '${box.barangay} · ${box.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${box.totalPorts} ports · ${box.occupiedPorts} occupied'
                    '${box.reservedPorts > 0 ? ' · ${box.reservedPorts} reserved' : ''}',
                    style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      );
}
