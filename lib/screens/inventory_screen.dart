import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/inventory_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Take items out of the stock of the branch, or bring them back. The admin approves each one.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _conditions = ['Good', 'Damaged', 'Defective'];
  static const _areas = ['Installation', 'Repair', 'Maintenance', 'Other'];

  String _type = 'out';
  List<StockItem> _available = const [];
  List<StockItem> _all = const [];
  String? _loadError;
  bool _loading = true;
  bool _submitting = false;
  String? _formError;

  StockItem? _item;
  int _quantity = 1;
  String _condition = 'Good';
  String _area = 'Installation';
  final _personController = TextEditingController();
  final _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _personController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  List<StockItem> get _items => _type == 'out' ? _available : _all;
  int get _maxQuantity => _type == 'out' ? (_item?.available ?? 1) : 9999;

  Future<void> _load() async {
    final result = await InventoryService.items();
    if (!mounted) return;
    setState(() {
      _available = result.available;
      _all = result.all;
      _loadError = result.error;
      _loading = false;
      _item = null;
      _quantity = 1;
    });
  }

  void _changeType(String type) {
    setState(() {
      _type = type;
      _item = null;
      _quantity = 1;
      _formError = null;
    });
  }

  Future<void> _next() async {
    final item = _item;
    if (item == null) {
      setState(() => _formError = 'Choose the item.');
      return;
    }
    if (_quantity < 1) {
      setState(() => _formError = 'Enter how many.');
      return;
    }
    setState(() => _formError = null);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _type == 'out' ? 'Confirm item out' : 'Confirm item return',
              style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _SummaryRow('Item', item.name),
            _SummaryRow('Quantity', '$_quantity'),
            _SummaryRow('Condition', _condition),
            if (_type == 'out') _SummaryRow('Used for', _area),
            if (_personController.text.trim().isNotEmpty) _SummaryRow('Person in charge', _personController.text.trim()),
            if (_remarksController.text.trim().isNotEmpty) _SummaryRow('Remarks', _remarksController.text.trim()),
            const SizedBox(height: 8),
            Text(
              _type == 'out'
                  ? 'The admin will approve this before the items are released to you.'
                  : 'The admin will check the items before they go back in stock.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Submit', onPressed: () => Navigator.pop(sheetContext, true)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(sheetContext, false), child: const Text('Back')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _submit(item);
  }

  Future<void> _submit(StockItem item) async {
    setState(() {
      _submitting = true;
      _formError = null;
    });
    final result = await InventoryService.submit(
      type: _type,
      inventoryId: item.id,
      quantity: _quantity,
      condition: _condition,
      areaUsed: _type == 'out' ? _area : '',
      personInCharge: _personController.text.trim(),
      comments: _remarksController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      showMessage(context, result['message']?.toString() ?? 'Submitted. Waiting for the admin.');
      _personController.clear();
      _remarksController.clear();
      await _load();
    } else {
      setState(() => _formError = result['message']?.toString() ?? 'Could not submit.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          SegmentedChoice<String>(
            values: const ['out', 'return'],
            labels: const ['Item Out', 'Item Return'],
            selected: _type,
            onChanged: _changeType,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            ErrorNotice(message: _loadError!, onRetry: _load)
          else
            _form(),
        ],
      ),
    );
  }

  Widget _form() {
    final items = _items;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        message: _type == 'out'
            ? 'There is no stock to take out right now in your branch.'
            : 'There are no stock items in your branch yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Item'),
        DropdownButtonFormField<StockItem>(
          key: ValueKey('item-$_type-${_item?.id}'),
          isExpanded: true,
          initialValue: _item,
          hint: const Text('Select item'),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(
                  _type == 'out' ? '${item.name}  (${item.available} available)' : item.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (item) => setState(() {
            _item = item;
            _quantity = 1;
          }),
        ),
        const FieldLabel('Quantity'),
        QuantityStepper(
          value: _quantity,
          min: 1,
          max: _maxQuantity,
          onChanged: (value) => setState(() => _quantity = value),
        ),
        const FieldLabel('Condition'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _condition,
          items: [for (final condition in _conditions) DropdownMenuItem(value: condition, child: Text(condition))],
          onChanged: (value) => setState(() => _condition = value ?? 'Good'),
        ),
        if (_type == 'out') ...[
          const FieldLabel('Area where used'),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _area,
            items: [for (final area in _areas) DropdownMenuItem(value: area, child: Text(area))],
            onChanged: (value) => setState(() => _area = value ?? 'Installation'),
          ),
        ],
        const FieldLabel('Person in charge'),
        TextField(
          controller: _personController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name of the person in charge'),
        ),
        const FieldLabel('Remarks (optional)'),
        TextField(
          controller: _remarksController,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Anything the admin should know'),
        ),
        if (_formError != null) FormError(_formError!),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Next', loading: _submitting, onPressed: _next),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}
