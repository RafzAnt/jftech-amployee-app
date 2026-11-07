import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Pick the NAP box and the port a client is plugged into. The boxes of the chosen barangay are listed; opening one shows its
/// ports: a free port can be picked, the others say who is plugged in or why they cannot be used.
class NapPortPicker extends StatefulWidget {
  /// The barangay whose NAP boxes are offered (empty until it is chosen).
  final String barangay;

  /// The port that is picked now, or null.
  final int? selectedPortId;

  /// Called with the port and its box when the person picks one, or with nulls when the choice no longer holds.
  final void Function(NapPort? port, NapBox? box) onChanged;

  const NapPortPicker({super.key, required this.barangay, required this.selectedPortId, required this.onChanged});

  @override
  State<NapPortPicker> createState() => _NapPortPickerState();
}

class _NapPortPickerState extends State<NapPortPicker> {
  List<NapBox> _boxes = const [];
  NapBox? _open;
  bool _loading = false;
  int? _loadingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBoxes();
  }

  @override
  void didUpdateWidget(NapPortPicker old) {
    super.didUpdateWidget(old);
    if (old.barangay != widget.barangay) {
      _open = null;
      _loadBoxes();
    }
  }

  Future<void> _loadBoxes() async {
    final barangay = widget.barangay;
    if (barangay.isEmpty) {
      setState(() {
        _boxes = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await FieldService.napBoxes(barangay: barangay);
    if (!mounted || barangay != widget.barangay) return;
    setState(() {
      _boxes = result.boxes;
      _error = result.error;
      _loading = false;
    });
  }

  Future<void> _openBox(NapBox box) async {
    if (_open?.id == box.id) {
      setState(() => _open = null);
      return;
    }
    setState(() {
      _loadingId = box.id;
      _error = null;
    });
    final result = await FieldService.napBox(box.id);
    if (!mounted) return;
    setState(() {
      _open = result.box;
      _error = result.error;
      _loadingId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.barangay.isEmpty) {
      return const _Hint('Choose the barangay first to see its NAP boxes.');
    }
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _boxes.isEmpty) {
      return ErrorNotice(message: _error!, onRetry: _loadBoxes);
    }
    if (_boxes.isEmpty) {
      return _Hint('There are no NAP boxes in ${widget.barangay} yet. Ask your admin to add them.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final box in _boxes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BoxTile(
              box: box,
              open: _open?.id == box.id ? _open : null,
              loading: _loadingId == box.id,
              selectedPortId: widget.selectedPortId,
              onToggle: () => _openBox(box),
              onPick: (port) => widget.onChanged(port, _open),
            ),
          ),
        if (_error != null) FormError(_error!),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      );
}

class _BoxTile extends StatelessWidget {
  final NapBox box;
  final NapBox? open;
  final bool loading;
  final int? selectedPortId;
  final VoidCallback onToggle;
  final ValueChanged<NapPort> onPick;

  const _BoxTile({
    required this.box,
    required this.open,
    required this.loading,
    required this.selectedPortId,
    required this.onToggle,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final detail = open;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                const Icon(Icons.router, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(box.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                      Text(
                        box.location.isEmpty ? box.barangay : '${box.barangay} · ${box.location}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  text: box.isFull ? 'Full' : '${box.availablePorts} free',
                  color: box.isFull ? AppColors.danger : AppColors.success,
                  background: box.isFull ? AppColors.dangerSoft : AppColors.successSoft,
                ),
                Icon(detail != null ? Icons.expand_less : Icons.expand_more, color: AppColors.muted),
              ],
            ),
          ),
          if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          if (detail != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final port in detail.ports)
                  _PortChip(port: port, selected: port.id == selectedPortId, onTap: port.isFree ? () => onPick(port) : null),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PortChip extends StatelessWidget {
  final NapPort port;
  final bool selected;
  final VoidCallback? onTap;

  const _PortChip({required this.port, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final free = port.isFree;
    final note = free ? (selected ? 'Selected' : 'Free') : (port.status == 'occupied' ? (port.clientName ?? 'In use') : port.statusLabel);
    return Tooltip(
      message: port.status == 'occupied'
          ? 'Port ${port.number} is connected to ${port.clientName ?? 'a client'}${port.clientCode == null ? '' : ' (${port.clientCode})'}'
          : 'Port ${port.number}: ${port.statusLabel}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : (free ? AppColors.surface : AppColors.background),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : (free ? AppColors.success : AppColors.border), width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Text(
                '${port.number}',
                style: TextStyle(color: free ? AppColors.text : AppColors.muted, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: selected ? AppColors.primary : AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
