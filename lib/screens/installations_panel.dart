import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/installation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'installation_form_screen.dart';

/// The Installation tab of the Inventory page: the items that wait for a report, the button to send one, and the reports sent so far
/// with what the admin did with them. It does not scroll by itself; it sits in the list of the Inventory page.
class InstallationsPanel extends StatefulWidget {
  /// Changes when the Inventory page is pulled to refresh, so the panel loads again.
  final int refreshToken;

  const InstallationsPanel({super.key, this.refreshToken = 0});

  @override
  State<InstallationsPanel> createState() => _InstallationsPanelState();
}

class _InstallationsPanelState extends State<InstallationsPanel> {
  List<InstallationReport> _reports = const [];
  List<TakenItem> _taken = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(InstallationsPanel old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([InstallationService.reports(), InstallationService.options()]);
    if (!mounted) return;
    final reports = results[0] as ({List<InstallationReport> reports, String? error});
    final options = results[1] as ({InstallationOptions? options, String? error});
    setState(() {
      _reports = reports.reports;
      _taken = options.options?.taken ?? const [];
      _error = reports.error ?? options.error;
      _loading = false;
    });
  }

  Future<void> _newReport() async {
    final message = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const InstallationFormScreen()));
    if (!mounted) return;
    if (message != null) showMessage(context, message);
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return ErrorNotice(message: _error!, onRetry: _load);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        if (_taken.isNotEmpty)
          AppCard(
            color: AppColors.warningSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _taken.length == 1 ? 'You have 1 approved installation waiting for a report' : 'You have ${_taken.length} approved installations waiting for a report',
                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final item in _taken)
                  Text('${item.quantity} × ${item.itemName}', style: const TextStyle(color: AppColors.text, fontSize: 13)),
              ],
            ),
          )
        else
          const Text(
            'After you install a client, send the report here: the NAP box and port, the client and the items you bring back. Your admin checks it and adds the client.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Report an installation', icon: Icons.add_task, onPressed: _newReport),
        const SectionTitle('My reports'),
        const SizedBox(height: 8),
        if (_reports.isEmpty)
          const EmptyState(icon: Icons.router_outlined, message: 'You have not sent an installation report yet.')
        else
          for (final report in _reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(report: report),
            ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final InstallationReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (report.napLabel.isNotEmpty) report.napLabel,
      report.barangay,
      if (report.planName.isNotEmpty) report.planName,
    ].where((part) => part.isNotEmpty).join(' • ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              StatusChip.forStatus(report.chipStatus, report.statusLabel),
            ],
          ),
          const SizedBox(height: 2),
          Text(details, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          if (report.taken.isNotEmpty)
            Text(
              'Took: ${report.taken.map((item) => '${item.quantity} × ${item.itemName}').join(', ')}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          if (report.returns.isNotEmpty)
            Text(
              'Returned: ${report.returns.map((line) => '${line.quantity} × ${line.itemName}').join(', ')}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          if (report.status == 'confirmed' && report.clientCode != null)
            Text('Client added: ${report.clientCode}', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
          if (report.status == 'rejected' && report.adminRemarks != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Admin: ${report.adminRemarks}', style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          const SizedBox(height: 4),
          Text(
            '${report.code} · ${shortDate(report.submittedAt)} ${shortTime(report.submittedAt)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
