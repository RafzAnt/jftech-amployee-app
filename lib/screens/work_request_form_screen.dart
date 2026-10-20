import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// An installation or repair request. The employee chooses the client, the barangay, the NAP box and an available
/// port (installation) or describes the problem (repair), and sends it to the admin for approval.
class WorkRequestFormScreen extends StatefulWidget {
  /// A request the admin returned for correction; the form starts with its details.
  final WorkRequest? editing;

  const WorkRequestFormScreen({super.key, this.editing});

  @override
  State<WorkRequestFormScreen> createState() => _WorkRequestFormScreenState();
}

class _WorkRequestFormScreenState extends State<WorkRequestFormScreen> {
  String _workType = 'installation';
  String _clientMode = 'existing';

  // The existing client.
  final _clientSearchController = TextEditingController();
  Timer? _searchDebounce;
  List<ClientSummary> _clientResults = const [];
  ClientSummary? _client;
  bool _searching = false;

  // The new client.
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Where and what.
  List<String> _barangays = const [];
  String? _barangay;
  List<NapBox> _boxes = const [];
  NapBox? _box;
  List<NapPort> _ports = const [];
  int? _portId;
  bool _loadingBoxes = false;
  final _locationController = TextEditingController();
  final _problemController = TextEditingController();

  String? _error;
  bool _submitting = false;

  bool get _isInstallation => _workType == 'installation';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _clientSearchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    _problemController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final barangays = await FieldService.barangays();
    if (!mounted) return;
    setState(() => _barangays = barangays);

    final editing = widget.editing;
    if (editing == null) return;

    setState(() {
      _workType = editing.workType;
      _clientMode = editing.isNewClient ? 'new' : 'existing';
      if (editing.isNewClient) {
        _nameController.text = editing.clientName;
        _phoneController.text = editing.clientPhone;
        _addressController.text = editing.clientAddress;
      } else if (editing.clientId != null) {
        _client = ClientSummary(
          id: editing.clientId!,
          code: '',
          name: editing.clientName,
          phone: editing.clientPhone,
          barangay: editing.barangay,
          address: editing.clientAddress,
        );
      }
      _barangay = barangays.contains(editing.barangay) ? editing.barangay : null;
      _locationController.text = editing.location;
      _problemController.text = editing.problemDetails;
    });

    if (editing.isInstallation && _barangay != null) {
      await _loadBoxes(selectBoxId: editing.napBoxId, selectPortId: editing.napPortId);
    }
  }

  // ---- clients --------------------------------------------------------------------------------

  void _searchClients(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final query = _clientSearchController.text;
      if (query.trim().length < 2) {
        if (mounted) setState(() => _clientResults = const []);
        return;
      }
      setState(() => _searching = true);
      final results = await FieldService.searchClients(query);
      if (!mounted) return;
      setState(() {
        _clientResults = results;
        _searching = false;
      });
    });
  }

  void _pickClient(ClientSummary client) {
    setState(() {
      _client = client;
      _clientResults = const [];
      _clientSearchController.clear();
      if (_barangays.contains(client.barangay) && _barangay != client.barangay) {
        _barangay = client.barangay;
        _box = null;
        _ports = const [];
        _portId = null;
      }
    });
    if (_isInstallation && _barangay != null) _loadBoxes();
  }

  // ---- NAP boxes ------------------------------------------------------------------------------

  Future<void> _loadBoxes({int? selectBoxId, int? selectPortId}) async {
    final barangay = _barangay;
    if (barangay == null) return;
    setState(() {
      _loadingBoxes = true;
      _boxes = const [];
      _box = null;
      _ports = const [];
      _portId = null;
    });
    final result = await FieldService.napBoxes(barangay: barangay);
    if (!mounted) return;
    NapBox? selected;
    for (final box in result.boxes) {
      if (box.id == selectBoxId) selected = box;
    }
    setState(() {
      _boxes = result.boxes;
      _loadingBoxes = false;
    });
    if (selected != null) await _chooseBox(selected, selectPortId: selectPortId);
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
    // The port the request already holds shows as reserved, so it stays selectable while it is being edited.
    final ownCode = widget.editing?.code;
    final usable = detail.box!.ports
        .where((port) => port.status == 'available' || (ownCode != null && port.reservedBy == ownCode))
        .toList();
    setState(() {
      _ports = usable;
      _portId = usable.any((port) => port.id == selectPortId) ? selectPortId : null;
    });
  }

  // ---- sending --------------------------------------------------------------------------------

  String? _validate() {
    if (_isInstallation) {
      if (_clientMode == 'existing' && _client == null) return 'Choose the client, or switch to New Client.';
      if (_clientMode == 'new') {
        if (_nameController.text.trim().length < 2) return 'Enter the full name of the new client.';
        if (!RegExp(r'^\d{11}$').hasMatch(_phoneController.text.trim())) return 'Mobile number must contain exactly 11 digits.';
        if (_addressController.text.trim().length < 3) return 'Enter the address of the new client.';
      }
      if (_barangay == null) return 'Choose the barangay.';
      if (_box == null) return 'Choose the NAP box.';
      if (_portId == null) return 'Choose an available port.';
    } else {
      if (_client == null) return 'Choose the client.';
      if (_problemController.text.trim().length < 3) return 'Describe the problem, for example no internet or a damaged cable.';
    }
    return null;
  }

  Map<String, dynamic> _payload() {
    final form = <String, dynamic>{'work_type': _workType};
    if (_isInstallation && _clientMode == 'new') {
      form['new_client'] = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
      };
    } else {
      form['client_id'] = _client?.id;
    }
    if (_barangay != null) form['barangay'] = _barangay;
    form['location'] = _locationController.text.trim();
    if (_isInstallation) {
      form['nap_box_id'] = _box?.id;
      form['nap_port_id'] = _portId;
    } else {
      form['problem_details'] = _problemController.text.trim();
    }
    return form;
  }

  Future<void> _next() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() => _error = null);

    NapPort? port;
    for (final candidate in _ports) {
      if (candidate.id == _portId) port = candidate;
    }
    final clientLine = _isInstallation && _clientMode == 'new'
        ? '${_nameController.text.trim()} (new client)'
        : (_client?.name ?? '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Review your request',
              style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            _ReviewRow('Work type', _isInstallation ? 'Installation' : 'Repair'),
            _ReviewRow('Client', clientLine),
            if (_barangay != null) _ReviewRow('Barangay', _barangay!),
            if (_isInstallation && _box != null) _ReviewRow('NAP box', _box!.name),
            if (_isInstallation && port != null) _ReviewRow('Port', 'Port ${port.number}'),
            if (!_isInstallation) _ReviewRow('Problem', _problemController.text.trim()),
            if (_locationController.text.trim().isNotEmpty)
              _ReviewRow(_isInstallation ? 'Location note' : 'Location', _locationController.text.trim()),
            const SizedBox(height: 8),
            const Text(
              'The admin will review it. You can start the work after it is approved.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Submit request', onPressed: () => Navigator.pop(sheetContext, true)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(sheetContext, false), child: const Text('Back')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await FieldService.submitWorkRequest(_payload(), requestId: widget.editing?.id);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      showMessage(context, result['message']?.toString() ?? 'Request submitted.');
      Navigator.pop(context, true);
    } else {
      setState(() => _error = result['message']?.toString() ?? 'Could not submit the request.');
    }
  }

  // ---- screen ---------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit request' : 'Installation Details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const FieldLabel('Work type'),
          SegmentedChoice<String>(
            values: const ['installation', 'repair'],
            labels: const ['Installation', 'Repair'],
            selected: _workType,
            onChanged: editing
                ? (_) {}
                : (value) => setState(() {
                      _workType = value;
                      if (value == 'repair') _clientMode = 'existing';
                      _error = null;
                    }),
          ),
          const SectionTitle('Client information'),
          if (_isInstallation) ...[
            const SizedBox(height: 8),
            SegmentedChoice<String>(
              values: const ['existing', 'new'],
              labels: const ['Existing Client', 'New Client'],
              selected: _clientMode,
              onChanged: (value) => setState(() {
                _clientMode = value;
                _error = null;
              }),
            ),
          ],
          if (_clientMode == 'existing' || !_isInstallation) _existingClient() else _newClient(),
          if (_isInstallation) ...[
            const SectionTitle('Where to connect'),
            _barangayField(),
            _napFields(),
            const FieldLabel('Location note (optional)'),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(hintText: 'Landmark or directions'),
            ),
          ] else ...[
            const SectionTitle('The problem'),
            const FieldLabel('Location'),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(hintText: 'Where is the problem? (optional)'),
            ),
            const FieldLabel('What is wrong?'),
            TextField(
              controller: _problemController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'For example no internet, or a damaged cable'),
            ),
          ],
          if (_error != null) FormError(_error!),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Next', loading: _submitting, onPressed: _next),
        ],
      ),
    );
  }

  Widget _existingClient() {
    final client = _client;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        if (client != null)
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                      Text(
                        [client.code, client.barangay].where((part) => part.isNotEmpty).join(' · '),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      if (client.isConnected)
                        Text(
                          'Connected to ${client.napBoxName} port ${client.napPortNumber}',
                          style: const TextStyle(color: AppColors.info, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                TextButton(onPressed: () => setState(() => _client = null), child: const Text('Change')),
              ],
            ),
          )
        else ...[
          TextField(
            controller: _clientSearchController,
            onChanged: _searchClients,
            decoration: const InputDecoration(
              hintText: 'Search by name, code or mobile number',
              prefixIcon: Icon(Icons.search, color: AppColors.muted),
            ),
          ),
          if (_searching)
            const Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
          else if (_clientSearchController.text.trim().length >= 2 && _clientResults.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('No client found.', style: TextStyle(color: AppColors.muted)),
            ),
          for (final result in _clientResults)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => _pickClient(result),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.name, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                          Text(
                            [result.code, result.barangay].where((part) => part.isNotEmpty).join(' · '),
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (result.isConnected)
                      const StatusChip(text: 'Connected', color: AppColors.info, background: AppColors.infoSoft),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _newClient() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Full name'),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Full name'),
          ),
          const FieldLabel('Phone number'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            decoration: const InputDecoration(hintText: '09XXXXXXXXX', counterText: ''),
          ),
          const FieldLabel('Address'),
          TextField(
            controller: _addressController,
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Complete address'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'The client is saved after the admin confirms the finished installation.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      );

  Widget _barangayField() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Barangay'),
          DropdownButtonFormField<String>(
            key: ValueKey('barangay-${_barangay ?? ''}'),
            isExpanded: true,
            initialValue: _barangay,
            hint: const Text('Select barangay'),
            items: [for (final name in _barangays) DropdownMenuItem(value: name, child: Text(name))],
            onChanged: (value) {
              setState(() => _barangay = value);
              _loadBoxes();
            },
          ),
        ],
      );

  Widget _napFields() {
    if (_barangay == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('NAP box'),
        if (_loadingBoxes)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)))
        else if (_boxes.isEmpty)
          const Text(
            'There is no NAP box in this barangay yet. Ask the admin to add one.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          )
        else
          DropdownButtonFormField<NapBox>(
            key: ValueKey('box-${_box?.id}'),
            isExpanded: true,
            initialValue: _box,
            hint: const Text('Select NAP box'),
            items: [
              for (final box in _boxes)
                DropdownMenuItem(
                  value: box,
                  enabled: !box.isFull || box.id == widget.editing?.napBoxId,
                  child: Text(
                    box.isFull ? '${box.name} (full)' : '${box.name} (${box.availablePorts} available)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _chooseBox,
          ),
        if (_box != null) ...[
          const FieldLabel('Port'),
          if (_ports.isEmpty)
            const Text('This NAP box has no available port.', style: TextStyle(color: AppColors.danger, fontSize: 13))
          else
            DropdownButtonFormField<int>(
              key: ValueKey('port-${_box?.id}-$_portId'),
              isExpanded: true,
              initialValue: _portId,
              hint: const Text('Select an available port'),
              items: [for (final port in _ports) DropdownMenuItem(value: port.id, child: Text('Port ${port.number}'))],
              onChanged: (value) => setState(() => _portId = value),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'The port is only reserved for you. It becomes occupied after the admin confirms the work.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
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
