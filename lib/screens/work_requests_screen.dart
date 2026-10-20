import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'work_request_detail_screen.dart';
import 'work_request_form_screen.dart';

/// The installation and repair requests of the employee, with where each one stands.
class WorkRequestsScreen extends StatefulWidget {
  const WorkRequestsScreen({super.key});

  @override
  State<WorkRequestsScreen> createState() => _WorkRequestsScreenState();
}

class _WorkRequestsScreenState extends State<WorkRequestsScreen> {
  String _filter = 'open';
  List<WorkRequest> _requests = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await FieldService.workRequests(status: _filter == 'open' ? 'open' : '');
    if (!mounted) return;
    setState(() {
      _requests = result.requests;
      _error = result.error;
      _loading = false;
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _filter = filter;
      _loading = true;
    });
    _load();
  }

  Future<void> _open(WorkRequest request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkRequestDetailScreen(requestId: request.id)),
    );
    _load();
  }

  Future<void> _create() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkRequestFormScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Work Requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            SegmentedChoice<String>(
              values: const ['open', 'all'],
              labels: const ['In progress', 'All'],
              selected: _filter,
              onChanged: _setFilter,
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              ErrorNotice(message: _error!, onRetry: _load)
            else if (_requests.isEmpty)
              const EmptyState(icon: Icons.assignment_outlined, message: 'No work requests here yet.')
            else
              for (final request in _requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestCard(request: request, onTap: () => _open(request)),
                ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final WorkRequest request;
  final VoidCallback onTap;

  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  request.isInstallation ? Icons.cable : Icons.build_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.typeLabel,
                    style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
                  ),
                ),
                StatusChip.forStatus(request.status, request.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.clientName,
              style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              [request.barangay, request.napLabel].where((part) => part.isNotEmpty).join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(request.code, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                const Spacer(),
                Text(shortDate(request.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
            if (request.status == 'returned' || request.status == 'approved') ...[
              const SizedBox(height: 8),
              Text(
                request.status == 'returned' ? 'Tap to correct and send it again' : 'Approved — tap to report the finished work',
                style: TextStyle(
                  color: request.status == 'returned' ? AppColors.danger : AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
}
