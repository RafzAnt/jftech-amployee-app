import 'package:flutter/material.dart';
import 'package:jftech/services/inventory_service.dart';
import 'inventory_history_screen.dart';

class InventoryRequestScreen extends StatefulWidget {
  const InventoryRequestScreen({super.key});

  @override
  State<InventoryRequestScreen> createState() => _InventoryRequestScreenState();
}

class _InventoryRequestScreenState extends State<InventoryRequestScreen> {
  static const _graphite = Color(0xFF14161C);
  static const _card = Color(0xFF1A1C23);
  static const _itemSurface = Color(0xFF23262F);
  static const _border = Color(0xFF2C2F38);
  static const _accent = Color(0xFF4C7EDB);
  static const _muted = Color(0xFF8A8D94);

  final List<InventoryRequestItem> _items = [];
  List<InventoryItem> _availableItems = [];
  final TextEditingController _commentsController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingItems = true;
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableItems();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableItems() async {
    setState(() => _isLoadingItems = true);
    final result = await InventoryService.getAvailableItems();
    if (!mounted) return;
    setState(() {
      _isLoadingItems = false;
      if (result['success'] == true) {
        _availableItems = List<InventoryItem>.from(result['data'] ?? []);
        _items
          ..clear()
          ..addAll(
            _availableItems.map(
              (item) => InventoryRequestItem(
                inventoryId: item.id,
                itemName: item.name,
                category: item.category,
                availableQuantity: item.availableQuantity,
                quantity: 0,
              ),
            ),
          );
      } else {
        _errorMessage = result['message'] ?? 'Unable to load inventory items';
      }
    });
  }

  Future<void> _submitRequest() async {
    setState(() {
      _isSubmitting = true;
      _successMessage = null;
      _errorMessage = null;
    });

    final hasItems = _items.any((item) => item.quantity > 0);
    if (!hasItems) {
      setState(() {
        _errorMessage = 'Please add quantity for at least one item';
        _isSubmitting = false;
      });
      return;
    }

    final result = await InventoryService.createRequest(
      _items,
      comments: _commentsController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        if (result['success'] == true) {
          _successMessage =
              result['message'] ?? 'Request submitted successfully!';
          _commentsController.clear();
          // Reload from the server so the remaining quantity reflects other
          // technicians' pending requests as well as this employee's request.
          _loadAvailableItems();
        } else {
          _errorMessage = result['message'] ?? 'Failed to submit request';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _graphite,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAvailableItems,
                color: _accent,
                backgroundColor: _card,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_successMessage != null)
                        _buildMessageCard(
                          _successMessage!,
                          const Color(0xFF5FAE7A),
                          Icons.check_circle_outline,
                        ),
                      if (_errorMessage != null)
                        _buildMessageCard(
                          _errorMessage!,
                          const Color(0xFFC95B5B),
                          Icons.error_outline,
                        ),
                      if (_successMessage != null || _errorMessage != null)
                        const SizedBox(height: 12),
                      _buildRequestCard(),
                      const SizedBox(height: 20),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    height: 58,
    padding: const EdgeInsets.only(left: 20, right: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFF22252E))),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'INVENTORY',
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
          icon: const Icon(Icons.history_outlined, color: _muted, size: 21),
          tooltip: 'View History',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InventoryHistoryScreen(),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildRequestCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.assignment_outlined, color: _accent, size: 20),
            SizedBox(width: 9),
            Text(
              'Select items',
              style: TextStyle(
                color: Color(0xFFE6E7EA),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 13),
          child: Divider(height: 1, color: _border),
        ),
        if (_isLoadingItems)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            ),
          )
        else if (_availableItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No items with available stock. Please contact the administrator.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          )
        else ...[
          const Text(
            'Enter the quantity needed for each item. Leave it blank or 0 if not needed.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ..._buildCategoryGroups(_items),
          const SizedBox(height: 2),
          _buildCommentsField(),
        ],
      ],
    ),
  );

  Widget _buildItemPair(InventoryRequestItem item) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: _itemSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Icon(_getIconForItem(item.itemName), color: _accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.itemName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE6E7EA),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${item.availableQuantity} available',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(width: 8),
              _buildQuantityChip(item),
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _buildCategoryGroups(List<InventoryRequestItem> items) {
    final grouped = <String, List<InventoryRequestItem>>{};
    for (final item in items) {
      final category = item.category.trim().isEmpty ? 'Other' : item.category;
      grouped.putIfAbsent(category, () => []).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    return sortedKeys.map((category) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.toUpperCase(),
              style: const TextStyle(
                color: _accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...grouped[category]!.map(_buildItemPair),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildCommentsField() => Container(
    decoration: BoxDecoration(
      color: _itemSurface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border),
    ),
    child: TextField(
      controller: _commentsController,
      minLines: 2,
      maxLines: 4,
      style: const TextStyle(color: Color(0xFFE6E7EA), fontSize: 12),
      decoration: const InputDecoration(
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 34),
          child: Icon(Icons.mode_comment_outlined, color: _muted, size: 18),
        ),
        hintText: 'Comment for this inventory (optional)',
        hintStyle: TextStyle(color: _muted, fontSize: 12),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      ),
    ),
  );

  Widget _buildQuantityChip(InventoryRequestItem item) => Container(
    width: 46,
    height: 30,
    decoration: BoxDecoration(
      color: _graphite,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _border),
    ),
    child: TextField(
      key: ValueKey('${item.inventoryId}-${item.quantity}'),
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Qty',
        hintStyle: TextStyle(color: _muted, fontSize: 10),
        contentPadding: EdgeInsets.only(bottom: 8),
      ),
      style: const TextStyle(
        color: Color(0xFFE6E7EA),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      controller: TextEditingController(
        text: item.quantity > 0 ? item.quantity.toString() : '',
      ),
      onChanged: (value) {
        final qty = int.tryParse(value);
        item.quantity = qty != null && qty > 0
            ? (qty > item.availableQuantity ? item.availableQuantity : qty)
            : 0;
      },
    ),
  );

  Widget _buildSubmitButton() => SizedBox(
    height: 48,
    child: ElevatedButton(
      onPressed: _isSubmitting ? null : _submitRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'SUBMIT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
    ),
  );

  Widget _buildMessageCard(String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForItem(String itemName) {
    switch (itemName.toLowerCase()) {
      case 'router':
        return Icons.router_outlined;
      case 'ups':
        return Icons.power_outlined;
      case 'patch cord':
        return Icons.cable_outlined;
      case 'cable tie':
        return Icons.circle_outlined;
      case 'pigtail':
        return Icons.settings_ethernet_outlined;
      case 'cable clamp':
        return Icons.horizontal_rule_rounded;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
