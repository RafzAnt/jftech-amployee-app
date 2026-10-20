import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'completion_report_screen.dart';
import 'work_request_form_screen.dart';

/// One request: its details, what the admin said, and what the employee can do next.
class WorkRequestDetailScreen extends StatefulWidget {
  final int requestId;

  const WorkRequestDetailScreen({super.key, required this.requestId});

  @override
  State<WorkRequestDetailScreen> createState() => _WorkRequestDetailScreenState();
}

class _WorkRequestDetailScreenState extends State<WorkRequestDetailScreen> {
  WorkRequest? _request;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await FieldService.workRequest(widget.requestId);
    if (!mounted) return;
    setState(() {
      _request = result.request;
      _error = result.error;
      _loading = false;
    });
  }

  Future<void> _edit(WorkRequest request) async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => WorkRequestFormScreen(editing: request)),
    );
    if (sent == true) _load();
  }

  Future<void> _report(WorkRequest request) async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CompletionReportScreen(request: request)),
    );
    if (sent == true) _load();
  }

  Future<void> _cancel(WorkRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text('The reserved NAP port is released and the request is closed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Cancel request')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await FieldService.cancelWorkRequest(request.id);
    if (!mounted) return;
    setState(() => _busy = false);
    showMessage(context, result['message']?.toString() ?? '', error: result['success'] != true);
    if (result['success'] == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      appBar: AppBar(title: Text(request?.code ?? 'Work request')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : request == null
              ? ErrorNotice(message: _error ?? 'That request was not found.', onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _content(request)),
    );
  }

  Widget _content(WorkRequest request) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.typeLabel,
                      style: const TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                  ),
                  StatusChip.forStatus(request.status, request.statusLabel),
                ],
              ),
              const SizedBox(height: 14),
              _Fact('Client', request.isNewClient ? '${request.clientName} (new client)' : request.clientName),
              if (request.clientPhone.isNotEmpty) _Fact('Mobile number', request.clientPhone),
              if (request.clientAddress.isNotEmpty) _Fact('Address', request.clientAddress),
              if (request.barangay.isNotEmpty) _Fact('Barangay', request.barangay),
              if (request.isInstallation && request.napBoxName != null)
                _Fact('Proposed NAP / port', '${request.napBoxName} · Port ${request.napPortNumber}'),
              if (request.location.isNotEmpty) _Fact(request.isInstallation ? 'Location note' : 'Location', request.location),
              if (!request.isInstallation) _Fact('Problem', request.problemDetails),
              _Fact('Sent', shortDate(request.createdAt)),
            ],
          ),
        ),
        if (request.adminRemarks.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x55F59E0B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Message from the admin', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 4),
                Text(request.adminRemarks, style: const TextStyle(color: AppColors.text)),
              ],
            ),
          ),
        ],
        if (request.completionNotes.isNotEmpty) ...[
          const SectionTitle('Completion report'),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.isInstallation && request.actualNapBoxName != null)
                  _Fact('NAP / port used', '${request.actualNapBoxName} · Port ${request.actualNapPortNumber}'),
                _Fact(request.isInstallation ? 'Notes' : 'Repair details', request.completionNotes),
                if (request.materials.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('Materials', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  for (final material in request.materials)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(material.itemName, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600))),
                          Text(
                            'used ${material.used} · returned ${material.returned} · damaged ${material.damaged}',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (request.canEdit) ...[
          PrimaryButton(label: 'Correct and send again', icon: Icons.edit_outlined, loading: _busy, onPressed: () => _edit(request)),
          const SizedBox(height: 10),
        ],
        if (request.canReport) ...[
          PrimaryButton(label: 'Submit completion report', icon: Icons.task_alt, loading: _busy, onPressed: () => _report(request)),
          const SizedBox(height: 10),
        ],
        if (request.status == 'work_completed')
          const Text(
            'Your report is with the admin. When it is confirmed, the port, the client and the stock are updated.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        if (request.canCancel)
          OutlinedButton(
            onPressed: _busy ? null : () => _cancel(request),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            child: const Text('Cancel request'),
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 118, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
