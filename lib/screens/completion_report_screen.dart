import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../services/inventory_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// What was really done: the NAP box and port that were used (installation), the notes, and the materials that
/// were used, brought back or damaged.
class CompletionReportScreen extends StatefulWidget {
  final WorkRequest request;

  const CompletionReportScreen({super.key, required this.request});

  @override
  State<CompletionReportScreen> createState() => _CompletionReportScreenState();
}

class _MaterialLine {
  StockItem? item;
  int used = 0;
  int returned = 0;
  int damaged = 0;
}

class _CompletionReportScreenState extends State<CompletionReportScreen> {
  final _notesController = TextEditingController();
  List<NapBox> _boxes = const [];
  NapBox? _box;
  List<NapPort> _ports = const [];
  int? _portId;
  List<StockItem> _stock = const [];
  final List<_MaterialLine> _lines = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  WorkRequest get _request => widget.request;

  @override
  void initState() {
    super.initState();
    _notesController.text = _request.completionNotes;
    for (final material in _request.materials) {
      _lines.add(_MaterialLine()
        ..used = material.used
        ..returned = material.returned
        ..damaged = material.damaged);
    }
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final stock = await InventoryService.items();
    List<NapBox> boxes = const [];
    if (_request.isInstallation) {
      final result = await FieldService.napBoxes(barangay: _request.barangay);
      boxes = result.boxes;
    }
    if (!mounted) return;

    // Materials reported earlier are matched to the stock items again.
    for (var i = 0; i < _lines.length && i < _request.materials.length; i++) {
      for (final item in stock.all) {
        if (item.id == _request.materials[i].inventoryId) _lines[i].item = item;
      }
    }

    setState(() {
      _stock = stock.all;
      _boxes = boxes;
      _loading = false;
    });

    if (_request.isInstallation) {
      final wantedBox = _request.actualNapBoxId ?? _request.napBoxId;
      for (final box in boxes) {
        if (box.id == wantedBox) {
          await _chooseBox(box, selectPortId: _request.actualNapPortId ?? _request.napPortId);
        }
      }
    }
  }

  Future<void> _chooseBox(NapBox? box, {int? selectPortId}) async {
    setState(() {
      _box = box;
      _ports = const [];
      _portId = null;
    });
    if (box == null) return;
    final detail = await FieldService.napBox(box.id);
    if (!mounted || detail.box == null) return;
    final usable = detail.box!.ports
        .where((port) => port.status == 'available' || port.reservedBy == _request.code)
        .toList();
    setState(() {
      _ports = usable;
      _portId = usable.any((port) => port.id == selectPortId) ? selectPortId : null;
    });
  }

  Future<void> _submit() async {
    if (_notesController.text.trim().length < 3) {
      setState(() => _error = _request.isInstallation
          ? 'Add a note about the installation.'
          : 'Describe the repair that was done.');
      return;
    }
    if (_request.isInstallation && (_box == null || _portId == null)) {
      setState(() => _error = 'Choose the NAP box and the port that were really used.');
      return;
    }

    final materials = <Map<String, dynamic>>[];
    for (final line in _lines) {
      if (line.item == null && (line.used + line.returned + line.damaged) > 0) {
        setState(() => _error = 'Choose the item for every material you filled in.');
        return;
      }
      if (line.item != null && (line.used + line.returned + line.damaged) > 0) {
        materials.add({
          'inventory_id': line.item!.id,
          'used_quantity': line.used,
          'returned_quantity': line.returned,
          'damaged_quantity': line.damaged,
        });
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await FieldService.completeWorkRequest(_request.id, {
      'completion_notes': _notesController.text.trim(),
      if (_request.isInstallation) 'actual_nap_box_id': _box!.id,
      if (_request.isInstallation) 'actual_nap_port_id': _portId,
      'materials': materials,
    });
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      showMessage(context, result['message']?.toString() ?? 'Report submitted.');
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result['message']?.toString() ?? 'Could not submit the report.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completion report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(_request.isInstallation ? Icons.cable : Icons.build_outlined, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_request.typeLabel} · ${_request.clientName}',
                                style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                            Text(_request.code, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_request.isInstallation) ...[
                  const SectionTitle('NAP box and port used'),
                  const FieldLabel('NAP box'),
                  DropdownButtonFormField<NapBox>(
                    key: ValueKey('report-box-${_box?.id}'),
                    isExpanded: true,
                    initialValue: _box,
                    hint: const Text('Select NAP box'),
                    items: [for (final box in _boxes) DropdownMenuItem(value: box, child: Text('${box.name} (${box.availablePorts} available)'))],
                    onChanged: _chooseBox,
                  ),
                  if (_box != null) ...[
                    const FieldLabel('Port'),
                    DropdownButtonFormField<int>(
                      key: ValueKey('report-port-${_box?.id}-$_portId'),
                      isExpanded: true,
                      initialValue: _portId,
                      hint: const Text('Select the port'),
                      items: [for (final port in _ports) DropdownMenuItem(value: port.id, child: Text('Port ${port.number}'))],
                      onChanged: (value) => setState(() => _portId = value),
                    ),
                  ],
                ],
                SectionTitle(_request.isInstallation ? 'Notes' : 'Repair details'),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: _request.isInstallation
                        ? 'For example connected and tested at 40 Mbps'
                        : 'What did you fix? For example replaced the damaged drop cable',
                  ),
                ),
                SectionTitle(
                  'Materials',
                  trailing: TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_MaterialLine())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ),
                if (_lines.isEmpty)
                  const Text(
                    'Add the items that were used, brought back or damaged. Leave it empty if no materials were used.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                for (var i = 0; i < _lines.length; i++) _materialCard(i),
                if (_error != null) FormError(_error!),
                const SizedBox(height: 22),
                PrimaryButton(label: 'Submit report', loading: _submitting, onPressed: _submit),
              ],
            ),
    );
  }

  Widget _materialCard(int index) {
    final line = _lines[index];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<StockItem>(
                    key: ValueKey('material-$index-${line.item?.id}'),
                    isExpanded: true,
                    initialValue: line.item,
                    hint: const Text('Select item'),
                    items: [for (final item in _stock) DropdownMenuItem(value: item, child: Text(item.name, overflow: TextOverflow.ellipsis))],
                    onChanged: (item) => setState(() => line.item = item),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _lines.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _countField('Used', line.used, (value) => setState(() => line.used = value))),
                const SizedBox(width: 8),
                Expanded(child: _countField('Returned', line.returned, (value) => setState(() => line.returned = value))),
                const SizedBox(width: 8),
                Expanded(child: _countField('Damaged', line.damaged, (value) => setState(() => line.damaged = value))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countField(String label, int value, ValueChanged<int> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: value > 0 ? () => onChanged(value - 1) : null,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.remove, size: 18, color: AppColors.primary),
                  ),
                ),
                Expanded(
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
                  ),
                ),
                InkWell(
                  onTap: () => onChanged(value + 1),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.add, size: 18, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
