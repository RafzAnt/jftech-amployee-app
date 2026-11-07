import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/installation_service.dart';
import '../services/inventory_service.dart';
import '../theme/app_theme.dart';
import '../utils/coordinates.dart';
import '../widgets/common.dart';
import '../widgets/nap_port_picker.dart';

/// The report after an installation: where it was installed, which NAP box and port, the client's details and the items brought
/// back. The admin confirms it before an inactive registered client becomes active and inventory is updated.
/// Pops with the server's message when the report was sent.
class InstallationFormScreen extends StatefulWidget {
  /// What the form offers and the stock to return from. Given only by tests; the app loads them from the server.
  final InstallationOptions? initialOptions;
  final List<StockItem> initialStock;

  const InstallationFormScreen({
    super.key,
    this.initialOptions,
    this.initialStock = const [],
  });

  @override
  State<InstallationFormScreen> createState() => _InstallationFormScreenState();
}

class _InstallationFormScreenState extends State<InstallationFormScreen> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _coordinates = TextEditingController();
  final _ip = TextEditingController();
  final _facebook = TextEditingController();
  final _remarks = TextEditingController();
  final _barangayController = TextEditingController();
  final _barangayFocus = FocusNode();
  final _nameFocus = FocusNode();

  InstallationOptions? _options;
  List<StockItem> _stock = const [];
  String? _loadError;
  bool _loading = true;
  bool _submitting = false;
  String? _formError;

  String? _barangay;
  int? _selectedClientId;

  /// The coordinates were filled in by the app (from the barangay or the NAP box) and the person has not typed their own yet, so a
  /// new barangay or a NAP box may still replace them.
  bool _coordinatesAuto = true;
  String? _coordinatesNote;
  int _locationTicket = 0;
  InstallationPlan? _plan;
  ChoiceOption? _mode;
  int? _portId;
  String _portLabel = '';
  final Set<int> _takenIds = {};
  final List<ReturnLine> _returns = [];

  @override
  void initState() {
    super.initState();
    final given = widget.initialOptions;
    if (given != null) {
      _options = given;
      _stock = widget.initialStock;
      _loading = false;
      _takenIds.addAll(given.taken.map((item) => item.id));
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _contact,
      _address,
      _coordinates,
      _ip,
      _facebook,
      _remarks,
      _barangayController,
    ]) {
      controller.dispose();
    }
    _barangayFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final results = await Future.wait([
      InstallationService.options(),
      InventoryService.items(),
    ]);
    if (!mounted) return;
    final options =
        results[0] as ({InstallationOptions? options, String? error});
    final stock =
        results[1]
            as ({
              List<StockItem> available,
              List<StockItem> all,
              String? error,
            });
    setState(() {
      _options = options.options;
      _stock = stock.all;
      _loadError =
          options.error ??
          (options.options == null ? 'Could not load the form.' : null);
      _loading = false;
      // What the technician took for installing is ticked from the start; they untick what belongs to another job.
      _takenIds
        ..clear()
        ..addAll(
          options.options?.taken.map((item) => item.id) ?? const <int>[],
        );
    });
  }

  Future<void> _pasteCoordinates() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      showMessage(
        context,
        'Nothing to paste. Copy the coordinates from Google Maps first.',
        error: true,
      );
      return;
    }
    setState(() {
      _coordinates.text = text;
      _coordinatesAuto = false; // the person's own value
      _coordinatesNote = null;
    });
  }

  /// The coordinates of the place, filled in unless the person has typed their own.
  void _setAutoCoordinates(String text, String note) {
    if (_coordinates.text.trim().isNotEmpty && !_coordinatesAuto) return;
    setState(() {
      _coordinates.text = text;
      _coordinatesAuto = true;
      _coordinatesNote = note;
    });
  }

  void _clearAutoCoordinates() {
    if (!_coordinatesAuto) return;
    setState(() {
      _coordinates.clear();
      _coordinatesNote = null;
    });
  }

  void _barangayTyped(String raw) {
    final value = raw.trim();
    if (value == _barangay) return;
    setState(() {
      _barangay = value.isEmpty ? null : value;
      _portId = null;
      _portLabel = '';
      // A client chosen from the previous barangay must not stay linked after changing location.
      if (_selectedClientId != null) {
        _selectedClientId = null;
        _name.clear();
        _contact.clear();
        _address.clear();
        _ip.clear();
        _facebook.clear();
        _plan = null;
        _mode = null;
      }
    });
    _locationTicket++;
    if (_coordinatesAuto) {
      _coordinates.clear();
      _coordinatesNote = null;
    }
  }

  void _chooseBarangay(String raw) {
    final value = raw.trim();
    _barangayController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {
      _barangay = value.isEmpty ? null : value;
      _portId = null;
      _portLabel = '';
    });
    if (value.isEmpty) {
      _locationTicket++;
      _clearAutoCoordinates();
    } else {
      _fillCoordinatesFromBarangay(value);
    }
  }

  void _selectRegisteredClient(
    RegisteredClient client,
    InstallationOptions options,
  ) {
    setState(() {
      _selectedClientId = client.id;
      _contact.text = client.contactNumber;
      _address.text = client.address;
      _ip.text = client.ipAddress;
      _facebook.text = client.facebookAccount;
      _coordinates.clear();
      _coordinatesAuto = true;
      _coordinatesNote = null;
      final plans = options.plans.where((plan) => plan.id == client.planId);
      final modes = options.paymentModes.where(
        (mode) => mode.value.toLowerCase() == client.paymentMode.toLowerCase(),
      );
      _plan = plans.isEmpty ? null : plans.first;
      _mode = modes.isEmpty ? null : modes.first;
    });
    _chooseBarangay(client.barangay);
  }

  void _clearRegisteredClient() {
    if (_selectedClientId == null) return;
    setState(() {
      _selectedClientId = null;
      _contact.clear();
      _address.clear();
      _ip.clear();
      _facebook.clear();
      _barangay = null;
      _barangayController.clear();
      _coordinates.clear();
      _coordinatesAuto = true;
      _coordinatesNote = null;
      _portId = null;
      _portLabel = '';
      _plan = null;
      _mode = null;
    });
  }

  /// The barangay was chosen: ask where it is and fill in the coordinates.
  Future<void> _fillCoordinatesFromBarangay(String barangay) async {
    final ticket = ++_locationTicket;
    if (_coordinates.text.trim().isNotEmpty && !_coordinatesAuto) return;
    setState(() => _coordinatesNote = 'Looking up $barangay…');
    final result = await InstallationService.barangayLocation(barangay);
    if (!mounted || ticket != _locationTicket) return;
    final place = result.place;
    if (place != null && place.found) {
      _setAutoCoordinates(place.coordinates, place.note);
    } else {
      setState(
        () => _coordinatesNote = place != null && !place.failed
            ? 'The place was not found on the map. Paste the coordinates from Google Maps.'
            : 'The map could not be asked now. Paste the coordinates from Google Maps.',
      );
    }
  }

  String? _validate() {
    if (_name.text.trim().length < 2) return 'Enter the name of the client.';
    if (!RegExp(r'^\d{11}$').hasMatch(_contact.text.trim()))
      return 'The contact number must have 11 digits, for example 09171234567.';
    if (_barangay == null || _barangay!.trim().isEmpty)
      return 'Choose the barangay.';
    if (_address.text.trim().isEmpty)
      return 'Enter the house number, street, purok or sitio.';
    final coordinatesProblem = coordinatesError(_coordinates.text);
    if (coordinatesProblem != null) return coordinatesProblem;
    if (_portId == null)
      return 'Choose the NAP box and the port the client is plugged into.';
    if (_plan == null) return 'Choose the plan of the client.';
    if (_mode == null) return 'Choose the mode of payment (MOP).';
    final ip = _ip.text.trim();
    if (ip.isNotEmpty && !_isIp(ip))
      return 'The IP address is not valid, for example 192.168.1.20.';
    return null;
  }

  bool _isIp(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return value.contains(':');
    return parts.every((part) {
      final number = int.tryParse(part);
      return number != null && number >= 0 && number <= 255;
    });
  }

  Future<void> _addReturn() async {
    final options = _options;
    if (options == null) return;
    final line = await showModalBottomSheet<ReturnLine>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) =>
          _ReturnSheet(stock: _stock, conditions: options.conditions),
    );
    if (line != null) setState(() => _returns.add(line));
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _formError = problem);
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });
    final result = await InstallationService.submit(
      InstallationDraft(
        fullName: _name.text,
        contactNumber: _contact.text,
        barangay: _barangay!,
        address: _address.text,
        planId: _plan!.id,
        clientId: _selectedClientId,
        paymentMode: _mode!.value,
        ipAddress: _ip.text,
        facebookAccount: _facebook.text,
        coordinates: _coordinates.text,
        napPortId: _portId!,
        requestIds: _takenIds.toList(),
        returns: _returns,
        remarks: _remarks.text,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      Navigator.pop(
        context,
        result['message']?.toString() ?? 'Installation report submitted.',
      );
    } else {
      setState(
        () => _formError =
            result['message']?.toString() ?? 'Could not send the report.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Installation Report')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? ErrorNotice(message: _loadError!, onRetry: _load)
            : _form(_options!),
      ),
    );
  }

  Widget _form(InstallationOptions options) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const Text(
          'Fill this in after the installation. Your admin checks the report and confirms the client account.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),

        const SectionTitle('Items you took'),
        if (options.taken.isEmpty)
          const AppCard(
            child: Text(
              'No approved installation request is waiting for a report. Request the items in Inventory first.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          )
        else
          for (final item in options.taken)
            CheckboxListTile(
              value: _takenIds.contains(item.id),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                '${item.quantity} × ${item.itemName}',
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Request #${item.id} · approved ${shortDate(item.approvedAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              onChanged: (checked) => setState(
                () => checked == true
                    ? _takenIds.add(item.id)
                    : _takenIds.remove(item.id),
              ),
            ),

        const SectionTitle('Where it was installed'),
        const FieldLabel('Barangay *'),
        RawAutocomplete<String>(
          textEditingController: _barangayController,
          focusNode: _barangayFocus,
          displayStringForOption: (name) => name,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const <String>[];
            return options.barangays
                .where((name) => name.toLowerCase().contains(query))
                .take(8);
          },
          onSelected: _chooseBarangay,
          optionsViewBuilder: (context, onSelected, names) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final name in names)
                      ListTile(
                        title: Text(name),
                        onTap: () => onSelected(name),
                      ),
                  ],
                ),
              ),
            ),
          ),
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) => TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: _barangayTyped,
                onEditingComplete: () {
                  _chooseBarangay(controller.text);
                  focusNode.unfocus();
                },
                decoration: const InputDecoration(
                  hintText: 'Type barangay to see suggestions',
                ),
              ),
        ),
        const FieldLabel('House No. / Street / Purok / Sitio *'),
        TextField(
          controller: _address,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Purok 1, Sitio name'),
        ),
        const FieldLabel('Google coordinates *'),
        TextField(
          controller: _coordinates,
          keyboardType: TextInputType.text,
          // Typing is the person's own value; the app filling the box does not come through here.
          onChanged: (_) => setState(() {
            _coordinatesAuto = false;
            _coordinatesNote = null;
          }),
          decoration: InputDecoration(
            hintText: '9.6541, 124.1234',
            helperText:
                _coordinatesNote ??
                'Fills in by itself from the barangay and the NAP box. To make it exact, press and hold the spot in Google Maps, copy the numbers and paste them here.',
            helperMaxLines: 4,
            suffixIcon: IconButton(
              onPressed: _pasteCoordinates,
              icon: const Icon(Icons.content_paste),
              tooltip: 'Paste',
            ),
          ),
        ),

        const SectionTitle('NAP box and port'),
        const SizedBox(height: 6),
        NapPortPicker(
          barangay: _barangay ?? '',
          selectedPortId: _portId,
          onChanged: (port, box) {
            setState(() {
              _portId = port?.id;
              _portLabel = port == null || box == null
                  ? ''
                  : '${box.name} · Port ${port.number}';
            });
            // The client is connected to this box, so the box is the best guess of where the client is.
            if (box != null && box.coordinates.isNotEmpty) {
              _setAutoCoordinates(
                box.coordinates,
                'Filled in from the NAP box ${box.name} the client is connected to. Move it to the exact house if you can.',
              );
            }
          },
        ),
        if (_portLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Connected to $_portLabel',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

        const SectionTitle('Client'),
        const FieldLabel('Name *'),
        RawAutocomplete<RegisteredClient>(
          textEditingController: _name,
          focusNode: _nameFocus,
          displayStringForOption: (client) => client.fullName,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            final barangay = _barangay?.trim().toLowerCase();
            if (barangay == null || barangay.isEmpty) {
              return const <RegisteredClient>[];
            }
            final inBarangay = options.clients.where(
              (client) => client.barangay.trim().toLowerCase() == barangay,
            );
            if (query.isEmpty) return inBarangay.take(8);
            return inBarangay
                .where(
                  (client) => client.fullName.toLowerCase().contains(query),
                )
                .take(8);
          },
          onSelected: (client) => _selectRegisteredClient(client, options),
          optionsViewBuilder: (context, onSelected, clients) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final client in clients)
                      ListTile(
                        title: Text(client.fullName),
                        subtitle: Text(
                          [
                            client.contactNumber,
                            client.barangay,
                          ].where((value) => value.isNotEmpty).join(' · '),
                        ),
                        onTap: () => onSelected(client),
                      ),
                  ],
                ),
              ),
            ),
          ),
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) => TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _clearRegisteredClient(),
                decoration: const InputDecoration(
                  hintText: 'Choose a barangay, then type a client name',
                ),
              ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 2),
          child: Text(
            !options.clientSuggestionsSupported
                ? 'Client suggestions are unavailable. The server needs the latest installation update.'
                : _barangay == null || _barangay!.trim().isEmpty
                ? 'Choose a barangay first, then type the client name to see matches.'
                : options.clients.isEmpty
                ? 'No inactive registered clients are available for this branch.'
                : options.clients.where((client) {
                    final barangay = _barangay?.trim().toLowerCase();
                    return barangay == null ||
                        barangay.isEmpty ||
                        client.barangay.trim().toLowerCase() == barangay;
                  }).isEmpty
                ? 'No inactive registered clients found in this barangay.'
                : 'Type a name to find an inactive client registered in ${_barangay!}.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const FieldLabel('Contact number *'),
        TextField(
          controller: _contact,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: const InputDecoration(hintText: '09171234567'),
        ),
        const FieldLabel('Plan *'),
        DropdownButtonFormField<InstallationPlan>(
          isExpanded: true,
          initialValue: _plan,
          hint: const Text('Select plan'),
          items: [
            for (final plan in options.plans)
              DropdownMenuItem(
                value: plan,
                child: Text(plan.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _plan = value),
        ),
        const FieldLabel('Mode of payment (MOP) *'),
        DropdownButtonFormField<ChoiceOption>(
          isExpanded: true,
          initialValue: _mode,
          hint: const Text('Select mode of payment'),
          items: [
            for (final mode in options.paymentModes)
              DropdownMenuItem(value: mode, child: Text(mode.label)),
          ],
          onChanged: (value) => setState(() => _mode = value),
        ),
        const FieldLabel('IP address'),
        TextField(
          controller: _ip,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '192.168.1.20'),
        ),
        const FieldLabel('Facebook account'),
        TextField(
          controller: _facebook,
          decoration: const InputDecoration(
            hintText: 'Name or link of the Facebook account',
          ),
        ),

        const SectionTitle('Items you bring back'),
        if (_returns.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Nothing to return? Skip this. Items left over go back in stock once your admin confirms.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        for (var i = 0; i < _returns.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_returns[i].quantity} × ${_returns[i].itemName}',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Condition: ${_returns[i].condition}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => setState(() => _returns.removeAt(i)),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _stock.isEmpty ? null : _addReturn,
          icon: const Icon(Icons.assignment_return_outlined),
          label: const Text('Return item'),
        ),

        const FieldLabel('Remarks (optional)'),
        TextField(
          controller: _remarks,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Anything the admin should know',
          ),
        ),

        if (_formError != null) FormError(_formError!),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Send report',
          icon: Icons.send_outlined,
          loading: _submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Choose one item, how many and its condition.
class _ReturnSheet extends StatefulWidget {
  final List<StockItem> stock;
  final List<String> conditions;

  const _ReturnSheet({required this.stock, required this.conditions});

  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  StockItem? _item;
  int _quantity = 1;
  late String _condition = widget.conditions.first;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Return item',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const FieldLabel('Item'),
          DropdownButtonFormField<StockItem>(
            isExpanded: true,
            initialValue: _item,
            hint: const Text('Select item'),
            items: [
              for (final item in widget.stock)
                DropdownMenuItem(
                  value: item,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (item) => setState(() => _item = item),
          ),
          const FieldLabel('Quantity'),
          QuantityStepper(
            value: _quantity,
            min: 1,
            onChanged: (value) => setState(() => _quantity = value),
          ),
          const FieldLabel('Condition'),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _condition,
            items: [
              for (final condition in widget.conditions)
                DropdownMenuItem(value: condition, child: Text(condition)),
            ],
            onChanged: (value) =>
                setState(() => _condition = value ?? widget.conditions.first),
          ),
          if (_error != null) FormError(_error!),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Add',
            onPressed: () {
              final item = _item;
              if (item == null) {
                setState(() => _error = 'Choose the item.');
                return;
              }
              Navigator.pop(
                context,
                ReturnLine(
                  inventoryId: item.id,
                  itemName: item.name,
                  quantity: _quantity,
                  condition: _condition,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
