import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// One NAP box with every port and who is connected to it.
class NapBoxDetailScreen extends StatefulWidget {
  final int boxId;
  final String name;

  const NapBoxDetailScreen({super.key, required this.boxId, required this.name});

  @override
  State<NapBoxDetailScreen> createState() => _NapBoxDetailScreenState();
}

class _NapBoxDetailScreenState extends State<NapBoxDetailScreen> {
  NapBox? _box;
  String? _error;
  bool _loading = true;
  Uint8List? _photo;
  bool _photoLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await FieldService.napBox(widget.boxId);
    if (!mounted) return;
    setState(() {
      _box = result.box;
      _error = result.error;
      _loading = false;
      _photoLoading = result.box?.hasPhoto ?? false;
      if (!(result.box?.hasPhoto ?? false)) _photo = null;
    });
    final box = result.box;
    if (box != null && box.hasPhoto) {
      final photo = await FieldService.napBoxPhoto(box.id, version: box.photoVersion);
      if (!mounted) return;
      setState(() {
        _photo = photo;
        _photoLoading = false;
      });
    }
  }

  void _openPhoto(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : box == null
              ? ErrorNotice(message: _error ?? 'That NAP box was not found.', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (box.hasPhoto) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 180,
                                  width: double.infinity,
                                  color: AppColors.primarySoft,
                                  child: _photo != null
                                      ? GestureDetector(
                                          onTap: () => _openPhoto(_photo!),
                                          child: Image.memory(_photo!, fit: BoxFit.cover, gaplessPlayback: true),
                                        )
                                      : Center(
                                          child: _photoLoading
                                              ? const CircularProgressIndicator()
                                              : const Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            Text(
                              box.name,
                              style: const TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    box.location.isEmpty ? box.barangay : '${box.barangay} · ${box.location}',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            if (box.coordinates.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: box.coordinates));
                                  showMessage(context, 'Coordinates copied. Paste them in Google Maps.');
                                },
                                child: Row(
                                  children: [
                                    const Icon(Icons.my_location, size: 16, color: AppColors.muted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        box.coordinates,
                                        style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const Icon(Icons.copy, size: 14, color: AppColors.muted),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _Count(label: 'Total ports', value: box.totalPorts, color: AppColors.text),
                                _Count(label: 'Occupied', value: box.occupiedPorts, color: AppColors.primary),
                                _Count(label: 'Available', value: box.availablePorts, color: AppColors.success),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SectionTitle('Port list'),
                      const SizedBox(height: 8),
                      for (final port in box.ports)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${port.number}',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Port ${port.number}', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                                      if (port.clientName != null)
                                        Text(
                                          port.clientCode == null ? port.clientName! : '${port.clientName} · ${port.clientCode}',
                                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                StatusChip.forStatus(port.displayStatus, port.statusLabel),
                              ],
                            ),
                          ),
                        ),
                      // The stock this NAP box is connected to: the unit taken when it was installed and what the jobs on it used.
                      const SectionTitle('Inventory used'),
                      const SizedBox(height: 8),
                      if (box.inventoryUsed.isEmpty)
                        const AppCard(
                          child: Text(
                            'No inventory has been used on this NAP box yet.',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        )
                      else
                        for (final entry in box.inventoryUsed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _InventoryLine(entry: entry),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _InventoryLine extends StatelessWidget {
  final NapInventoryEntry entry;

  const _InventoryLine({required this.entry});

  @override
  Widget build(BuildContext context) {
    final who = [
      if (entry.employeeName != null) entry.employeeName!,
      if (entry.clientLabel.isNotEmpty) entry.clientLabel,
    ].join(' • ');
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.itemName, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${entry.typeLabel} • ${shortDate(entry.occurredAt)} ${shortTime(entry.occurredAt)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (who.isNotEmpty) Text(who, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          if (entry.quantityLabel.isNotEmpty)
            Text(
              entry.quantityLabel,
              style: TextStyle(
                color: entry.quantityChange < 0 ? AppColors.danger : AppColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Count({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      );
}
