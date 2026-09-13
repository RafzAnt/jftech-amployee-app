import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/inventory_service.dart';

class InventoryHistoryScreen extends StatefulWidget {
  const InventoryHistoryScreen({super.key});

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  static const _graphite = Color(0xFF14161C);
  static const _card = Color(0xFF1A1C23);
  static const _border = Color(0xFF2C2F38);
  static const _accent = Color(0xFF4C7EDB);
  static const _muted = Color(0xFF8A8D94);

  List<InventoryRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await InventoryService.getMyRequests();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _requests = result['data'] ?? [];
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
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: _muted, size: 19),
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
            ),
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
              onPressed: _loadRequests,
              tooltip: 'Refresh',
            ),
          ],
        ),
      );

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
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
              TextButton(onPressed: _loadRequests, child: const Text('RETRY', style: TextStyle(color: _accent))),
            ],
          ),
        ),
      );
    }
    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: _accent, size: 42),
            SizedBox(height: 12),
              Text('No inventory items yet', style: TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: _accent,
      backgroundColor: _card,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
      ),
    );
  }

  Widget _buildRequestCard(InventoryRequest request) {
    final statusColor = _statusColor(request);
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.55)),
                  ),
                  child: Text(_statusLabel(request), style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
                ),
                const Spacer(),
                Text(request.formattedDate, style: const TextStyle(color: _muted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: Text(_statusMessage(request), style: TextStyle(color: statusColor, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF23262F),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _accent),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: _accent, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.itemName, style: const TextStyle(color: Color(0xFFE6E7EA), fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text('Qty: ${request.quantity}', style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFF22252E)),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(Icons.mode_comment_outlined, color: _muted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.comments.isEmpty ? 'No comment provided' : request.comments,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (request.processedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Processed: ${DateFormat('MMM dd, yyyy hh:mm a').format(request.processedAt!)}',
                style: const TextStyle(color: Color(0xFF5E6168), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(InventoryRequest request) {
    if (request.isApproved) return const Color(0xFF5FAE7A);
    if (request.isPending) return const Color(0xFFE28A62);
    return const Color(0xFFC95B5B);
  }

  String _statusLabel(InventoryRequest request) {
    if (request.isApproved) return 'Approved';
    if (request.isPending) return 'Pending';
    return 'Rejected';
  }

  String _statusMessage(InventoryRequest request) {
    if (request.isApproved) return 'Approved. Item will be released to you.';
    if (request.isPending) return 'Waiting for administrator approval.';
    return 'Request was not approved. Contact the administrator if needed.';
  }
}
