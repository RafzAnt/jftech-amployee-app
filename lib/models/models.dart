// The things the server sends to the app, as plain Dart objects.

int _int(dynamic value, [int fallback = 0]) =>
    value == null ? fallback : (int.tryParse(value.toString()) ?? fallback);

String _text(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _textOrNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

double? _doubleOrNull(dynamic value) =>
    value == null ? null : double.tryParse(value.toString());

List<Map<String, dynamic>> _rows(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

/// "08:05:00" as "8:05 AM". Empty when there is no time.
String clockTime(String? value) {
  if (value == null || value.length < 5) return '';
  final hour = int.tryParse(value.substring(0, 2));
  final minute = value.substring(3, 5);
  if (hour == null) return '';
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:$minute ${hour < 12 ? 'AM' : 'PM'}';
}

/// Minutes as "1h 15m" (or "45m" below an hour, "0m" for none).
String durationLabel(int minutes) {
  if (minutes <= 0) return '0m';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

/// The person who is signed in, with what they did today.
class MeInfo {
  final int id;
  final String fullName;
  final String position;
  final String branch;
  final TodayAttendance today;
  final int pendingInventory;

  /// Approved installation requests that still wait for the employee's installation report.
  final int awaitingInstallationReports;

  const MeInfo({
    required this.id,
    required this.fullName,
    required this.position,
    required this.branch,
    required this.today,
    required this.pendingInventory,
    this.awaitingInstallationReports = 0,
  });

  factory MeInfo.fromJson(Map<String, dynamic> json) {
    final employee = Map<String, dynamic>.from(json['employee'] as Map? ?? {});
    return MeInfo(
      id: _int(employee['id']),
      fullName: _text(employee['full_name'], 'Employee'),
      position: _text(employee['position']),
      branch: _text(employee['branch_name']),
      today: TodayAttendance.fromJson(
        Map<String, dynamic>.from(json['today'] as Map? ?? {}),
      ),
      pendingInventory: _int(json['pending_inventory_requests']),
      awaitingInstallationReports: _int(json['awaiting_installation_reports']),
    );
  }
}

class TodayAttendance {
  final String? checkInTime;
  final String? morningIn;
  final String? morningOut;
  final String? afternoonIn;
  final String? afternoonOut;
  final String? overtimeIn;
  final String? overtimeOut;
  final int overtimeMinutes;

  /// A day of overtime is paid only from this many minutes (the server says; an hour unless the business changes it).
  final int overtimeMinimumMinutes;
  final double? totalHours;
  final bool checkedIn;
  final bool onDuty;

  const TodayAttendance({
    this.checkInTime,
    this.morningIn,
    this.morningOut,
    this.afternoonIn,
    this.afternoonOut,
    this.overtimeIn,
    this.overtimeOut,
    this.overtimeMinutes = 0,
    this.overtimeMinimumMinutes = 60,
    this.totalHours,
    this.checkedIn = false,
    this.onDuty = false,
  });

  factory TodayAttendance.fromJson(Map<String, dynamic> json) =>
      TodayAttendance(
        checkInTime: _textOrNull(json['check_in_time']),
        morningIn: _textOrNull(json['morning_time_in']),
        morningOut: _textOrNull(json['morning_time_out']),
        afternoonIn: _textOrNull(json['afternoon_time_in']),
        afternoonOut: _textOrNull(json['afternoon_time_out']),
        overtimeIn: _textOrNull(json['overtime_time_in']),
        overtimeOut: _textOrNull(json['overtime_time_out']),
        overtimeMinutes: _int(json['overtime_minutes']),
        overtimeMinimumMinutes: _int(json['overtime_minimum_minutes'], 60),
        totalHours: _doubleOrNull(json['total_hours']),
        checkedIn: json['checked_in'] == true,
        onDuty: json['on_duty'] == true,
      );

  /// The hours worked today as "2h 45m". Counts up to now while the employee is still on duty.
  String hoursLabel(DateTime now) {
    var seconds = 0;
    seconds += _span(morningIn, morningOut, now);
    seconds += _span(afternoonIn, afternoonOut, now);
    seconds += _span(overtimeIn, overtimeOut, now);
    if (seconds == 0 && totalHours != null)
      seconds = (totalHours! * 3600).round();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  /// The overtime has been started and not ended yet.
  bool get overtimeRunning => overtimeIn != null && overtimeOut == null;

  /// The overtime of the day is long enough to be paid.
  bool get overtimeCounted => overtimeMinutes >= overtimeMinimumMinutes;

  /// The overtime of the day as "1h 30m", or empty when there is none.
  String get overtimeLabel {
    if (overtimeIn == null) return '';
    final minutes = overtimeRunning
        ? _span(overtimeIn, null, DateTime.now()) ~/ 60
        : overtimeMinutes;
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  int _span(String? timeIn, String? timeOut, DateTime now) {
    final start = _secondsOfDay(timeIn);
    if (start == null) return 0;
    final end =
        _secondsOfDay(timeOut) ??
        (now.hour * 3600 + now.minute * 60 + now.second);
    return end > start ? end - start : 0;
  }

  int? _secondsOfDay(String? value) {
    if (value == null || value.length < 5) return null;
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    if (hour == null || minute == null) return null;
    return hour * 3600 + minute * 60 + second;
  }
}

class NapPort {
  final int id;
  final int number;

  /// available, occupied or faulty.
  final String status;
  final String? clientName;
  final String? clientCode;

  /// A free port that another technician has already used in an installation report the admin has not confirmed yet.
  final bool reserved;

  const NapPort({
    required this.id,
    required this.number,
    required this.status,
    this.clientName,
    this.clientCode,
    this.reserved = false,
  });

  factory NapPort.fromJson(Map<String, dynamic> json) => NapPort(
    id: _int(json['id']),
    number: _int(json['port_number']),
    status: _text(json['status'], 'available'),
    clientName: _textOrNull(json['client_name']),
    clientCode: _textOrNull(json['client_code']),
    reserved: json['reserved'] == true,
  );

  /// What to show: a reserved port is neither free nor connected yet.
  String get displayStatus => reserved ? 'reserved' : status;

  String get statusLabel {
    final shown = displayStatus;
    return shown.isEmpty ? '' : shown[0].toUpperCase() + shown.substring(1);
  }

  /// The port can be given to a new client.
  bool get isFree => status == 'available' && !reserved;
}

/// One stock transaction that belongs to a NAP box: the unit taken from the stock when it was installed.
class NapInventoryEntry {
  final String occurredAt;
  final String itemName;
  final String typeLabel;
  final int quantityChange;
  final String? employeeName;
  final String? clientName;
  final String? clientCode;
  final String? remarks;

  const NapInventoryEntry({
    required this.occurredAt,
    required this.itemName,
    required this.typeLabel,
    required this.quantityChange,
    this.employeeName,
    this.clientName,
    this.clientCode,
    this.remarks,
  });

  factory NapInventoryEntry.fromJson(Map<String, dynamic> json) =>
      NapInventoryEntry(
        occurredAt: _text(json['occurred_at']),
        itemName: _text(json['item_name']),
        typeLabel: _text(json['type_label']),
        quantityChange: _int(json['quantity_change']),
        employeeName: _textOrNull(json['employee_name']),
        clientName: _textOrNull(json['client_name']),
        clientCode: _textOrNull(json['client_code']),
        remarks: _textOrNull(json['remarks']),
      );

  /// "Out 1", "In 2", or empty when the line only records where items went.
  String get quantityLabel => quantityChange == 0
      ? ''
      : '${quantityChange < 0 ? 'Out' : 'In'} ${quantityChange.abs()}';

  /// "Ana Reyes · JFT-1", or empty.
  String get clientLabel => clientName == null
      ? ''
      : (clientCode == null ? clientName! : '$clientName · $clientCode');
}

class NapBox {
  final int id;
  final String name;
  final String barangay;
  final String location;
  final int totalPorts;
  final int occupiedPorts;
  final int faultyPorts;
  final int availablePorts;

  /// Where the box hangs, as "9.654100, 124.123400" (empty when the admin has not entered it).
  final String coordinates;
  final List<NapPort> ports;

  /// The stock transactions of this box (only sent with a single box, not in the list).
  final List<NapInventoryEntry> inventoryUsed;

  /// Whether the admin has put a photo of the box, and its version (it changes with the photo).
  final bool hasPhoto;
  final String? photoVersion;

  const NapBox({
    required this.id,
    required this.name,
    required this.barangay,
    required this.location,
    required this.totalPorts,
    required this.occupiedPorts,
    required this.faultyPorts,
    required this.availablePorts,
    this.coordinates = '',
    this.ports = const [],
    this.inventoryUsed = const [],
    this.hasPhoto = false,
    this.photoVersion,
  });

  factory NapBox.fromJson(Map<String, dynamic> json) => NapBox(
    id: _int(json['id']),
    name: _text(json['name']),
    barangay: _text(json['barangay_name']),
    location: _text(json['location']),
    totalPorts: _int(json['total_ports']),
    occupiedPorts: _int(json['occupied_ports']),
    faultyPorts: _int(json['faulty_ports']),
    availablePorts: _int(json['available_ports']),
    coordinates: _text(json['coordinates']),
    ports: _rows(json['ports']).map(NapPort.fromJson).toList(),
    inventoryUsed: _rows(
      json['inventory_used'],
    ).map(NapInventoryEntry.fromJson).toList(),
    hasPhoto: json['has_photo'] == true,
    photoVersion: _textOrNull(json['photo_version']),
  );

  bool get isFull => availablePorts == 0;
}

/// One line of the transaction history: an item out or an item return.
class TransactionEntry {
  final String kind;
  final int id;
  final String code;
  final String title;
  final String subtitle;
  final String detail;
  final String status;
  final String statusLabel;
  final String occurredAt;

  /// When and by whom an item request was approved or denied (empty while it waits).
  final String decidedAt;
  final String decidedBy;

  const TransactionEntry({
    required this.kind,
    required this.id,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.status,
    required this.statusLabel,
    required this.occurredAt,
    this.decidedAt = '',
    this.decidedBy = '',
  });

  factory TransactionEntry.fromJson(Map<String, dynamic> json) =>
      TransactionEntry(
        kind: _text(json['kind']),
        id: _int(json['id']),
        code: _text(json['code']),
        title: _text(json['title']),
        subtitle: _text(json['subtitle']),
        detail: _text(json['detail']),
        status: _text(json['status']),
        statusLabel: _text(json['status_label']),
        occurredAt: _text(json['occurred_at']),
        decidedAt: _text(json['decided_at']),
        decidedBy: _text(json['decided_by']),
      );
}

/// A stock item the employee can take or bring back.
class StockItem {
  final int id;
  final String name;
  final String category;
  final int available;
  final int quantity;

  const StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.available,
    required this.quantity,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
    id: _int(json['id']),
    name: _text(json['item_name']),
    category: _text(json['category'], 'Other'),
    available: _int(json['available_quantity'] ?? json['quantity']),
    quantity: _int(json['quantity']),
  );
}

/// A day of the attendance history.
class AttendanceDay {
  final String date;
  final String? morningIn;
  final String? morningOut;
  final String? afternoonIn;
  final String? afternoonOut;
  final String? overtimeIn;
  final String? overtimeOut;
  final int overtimeMinutes;

  /// Minutes the day started after the start of a session marked late.
  final int lateMinutes;

  /// Minutes a session was left before it ended (the server leaves a few minutes of grace out).
  final int undertimeMinutes;
  final String statusMorning;
  final String statusAfternoon;
  final double? totalHours;
  final String branch;

  const AttendanceDay({
    required this.date,
    this.morningIn,
    this.morningOut,
    this.afternoonIn,
    this.afternoonOut,
    this.overtimeIn,
    this.overtimeOut,
    this.overtimeMinutes = 0,
    this.lateMinutes = 0,
    this.undertimeMinutes = 0,
    this.statusMorning = '',
    this.statusAfternoon = '',
    this.totalHours,
    this.branch = '',
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
    date: _text(json['attendance_date']),
    morningIn: _textOrNull(json['morning_time_in']),
    morningOut: _textOrNull(json['morning_time_out']),
    afternoonIn: _textOrNull(json['afternoon_time_in']),
    afternoonOut: _textOrNull(json['afternoon_time_out']),
    overtimeIn: _textOrNull(json['overtime_time_in']),
    overtimeOut: _textOrNull(json['overtime_time_out']),
    overtimeMinutes: _int(json['overtime_minutes']),
    lateMinutes: _int(json['late_minutes']),
    undertimeMinutes: _int(json['undertime_minutes']),
    statusMorning: _text(json['status_morning']),
    statusAfternoon: _text(json['status_afternoon']),
    totalHours: _doubleOrNull(json['total_hours']),
    branch: _text(json['branch_name']),
  );

  /// The day was complete: both sessions worked, on time and to the end.
  bool get complete =>
      morningIn != null &&
      afternoonIn != null &&
      statusMorning == 'present' &&
      statusAfternoon == 'present' &&
      undertimeMinutes == 0;
}

/// The totals the server works out for the days of the history list.
class AttendanceSummary {
  final int daysRecorded;
  final double daysWorked;
  final int lateMinutes;
  final int undertimeMinutes;
  final int overtimeMinutes;

  /// A day of overtime is paid only from this many minutes.
  final int overtimeMinimumMinutes;
  final double totalHours;
  final int absentSessions;

  const AttendanceSummary({
    this.daysRecorded = 0,
    this.daysWorked = 0,
    this.lateMinutes = 0,
    this.undertimeMinutes = 0,
    this.overtimeMinutes = 0,
    this.overtimeMinimumMinutes = 60,
    this.totalHours = 0,
    this.absentSessions = 0,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) =>
      AttendanceSummary(
        daysRecorded: _int(json['days_recorded']),
        daysWorked: _doubleOrNull(json['days_worked']) ?? 0,
        lateMinutes: _int(json['late_minutes']),
        undertimeMinutes: _int(json['undertime_minutes']),
        overtimeMinutes: _int(json['overtime_minutes']),
        overtimeMinimumMinutes: _int(json['overtime_minimum_minutes'], 60),
        totalHours: _doubleOrNull(json['total_hours']) ?? 0,
        absentSessions: _int(json['absent_sessions']),
      );
}

// ---- installation reports ---------------------------------------------------------------------

/// An internet plan the client can be given.
class InstallationPlan {
  final int id;
  final String name;
  final int speedMbps;
  final double monthlyPrice;

  const InstallationPlan({
    required this.id,
    required this.name,
    required this.speedMbps,
    required this.monthlyPrice,
  });

  factory InstallationPlan.fromJson(Map<String, dynamic> json) =>
      InstallationPlan(
        id: _int(json['id']),
        name: _text(json['plan_name']),
        speedMbps: _int(json['speed_mbps']),
        monthlyPrice: _doubleOrNull(json['monthly_price']) ?? 0,
      );

  /// "Starter (100 Mbps) - P999/mo"
  String get label =>
      '$name ($speedMbps Mbps) - \u20b1${monthlyPrice.toStringAsFixed(0)}/mo';
}

/// A value the server understands and the words the person reads (the mode of payment).
class ChoiceOption {
  final String value;
  final String label;

  const ChoiceOption({required this.value, required this.label});

  factory ChoiceOption.fromJson(Map<String, dynamic> json) =>
      ChoiceOption(value: _text(json['value']), label: _text(json['label']));
}

/// A branch client's details, offered when they have not been connected to a NAP port yet.
class RegisteredClient {
  final int id;
  final String fullName;
  final String contactNumber;
  final String barangay;
  final String address;
  final int? planId;
  final String paymentMode;
  final String ipAddress;
  final String facebookAccount;

  const RegisteredClient({
    required this.id,
    required this.fullName,
    required this.contactNumber,
    required this.barangay,
    required this.address,
    this.planId,
    required this.paymentMode,
    required this.ipAddress,
    required this.facebookAccount,
  });

  factory RegisteredClient.fromJson(Map<String, dynamic> json) =>
      RegisteredClient(
        id: _int(json['id']),
        fullName: _text(json['full_name']),
        contactNumber: _text(json['contact_number']),
        barangay: _text(json['barangay_name']),
        address: _text(json['exact_address']),
        planId: json['internet_plan_id'] == null
            ? null
            : _int(json['internet_plan_id']),
        paymentMode: _text(json['payment_mode']),
        ipAddress: _text(json['ip_address']),
        facebookAccount: _text(json['facebook_account']),
      );
}

/// An approved item-out request for an installation: what the technician took.
class TakenItem {
  final int id;
  final String itemName;
  final int quantity;
  final String approvedAt;

  const TakenItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    this.approvedAt = '',
  });

  factory TakenItem.fromJson(Map<String, dynamic> json) => TakenItem(
    id: _int(json['id']),
    itemName: _text(json['item_name']),
    quantity: _int(json['quantity']),
    approvedAt: _text(json['approved_at']),
  );
}

/// What the installation report form offers.
class InstallationOptions {
  final List<String> barangays;
  final List<InstallationPlan> plans;
  final List<RegisteredClient> clients;
  final bool clientSuggestionsSupported;
  final List<ChoiceOption> paymentModes;
  final List<String> conditions;
  final List<TakenItem> taken;

  const InstallationOptions({
    this.barangays = const [],
    this.plans = const [],
    this.clients = const [],
    this.clientSuggestionsSupported = true,
    this.paymentModes = const [],
    this.conditions = const ['Good', 'Damaged', 'Defective'],
    this.taken = const [],
  });

  factory InstallationOptions.fromJson(Map<String, dynamic> json) {
    final conditions = json['conditions'];
    return InstallationOptions(
      barangays: json['barangays'] is List
          ? (json['barangays'] as List).map((name) => name.toString()).toList()
          : const [],
      plans: _rows(json['plans']).map(InstallationPlan.fromJson).toList(),
      clients: _rows(json['clients']).map(RegisteredClient.fromJson).toList(),
      clientSuggestionsSupported: json['clients'] is List,
      paymentModes: _rows(
        json['payment_modes'],
      ).map(ChoiceOption.fromJson).toList(),
      conditions: conditions is List && conditions.isNotEmpty
          ? conditions.map((name) => name.toString()).toList()
          : const ['Good', 'Damaged', 'Defective'],
      taken: _rows(json['taken']).map(TakenItem.fromJson).toList(),
    );
  }
}

/// One item the technician brings back after the installation.
class ReturnLine {
  final int inventoryId;
  final String itemName;
  final int quantity;
  final String condition;

  const ReturnLine({
    required this.inventoryId,
    required this.itemName,
    required this.quantity,
    required this.condition,
  });
}

/// What the technician fills in after installing a client; the admin checks it before linking or adding the client.
class InstallationDraft {
  final String fullName;
  final String contactNumber;
  final String barangay;
  final String address;
  final int planId;
  final int? clientId;
  final String paymentMode;
  final String ipAddress;
  final String facebookAccount;
  final String coordinates;
  final int napPortId;
  final List<int> requestIds;
  final List<ReturnLine> returns;
  final String remarks;

  const InstallationDraft({
    required this.fullName,
    required this.contactNumber,
    required this.barangay,
    required this.address,
    required this.planId,
    this.clientId,
    required this.paymentMode,
    required this.coordinates,
    required this.napPortId,
    this.ipAddress = '',
    this.facebookAccount = '',
    this.requestIds = const [],
    this.returns = const [],
    this.remarks = '',
  });

  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'contact_number': contactNumber.trim(),
    'barangay_name': barangay,
    'exact_address': address.trim(),
    'internet_plan_id': planId,
    'client_id': clientId,
    'payment_mode': paymentMode,
    'ip_address': ipAddress.trim(),
    'facebook_account': facebookAccount.trim(),
    'coordinates': coordinates.trim(),
    'nap_port_id': napPortId,
    'request_ids': requestIds,
    'returns': [
      for (final line in returns)
        {
          'inventory_id': line.inventoryId,
          'quantity': line.quantity,
          'item_condition': line.condition,
        },
    ],
    'remarks': remarks.trim(),
  };
}

/// An item that came back with a report, and how many the admin put back in stock.
class ReportReturn {
  final String itemName;
  final int quantity;
  final int? acceptedQuantity;
  final String condition;

  const ReportReturn({
    required this.itemName,
    required this.quantity,
    this.acceptedQuantity,
    required this.condition,
  });

  factory ReportReturn.fromJson(Map<String, dynamic> json) => ReportReturn(
    itemName: _text(json['item_name']),
    quantity: _int(json['quantity']),
    acceptedQuantity: json['accepted_quantity'] == null
        ? null
        : _int(json['accepted_quantity']),
    condition: _text(json['item_condition'], 'Good'),
  );
}

/// A report the technician sent: waiting for the admin, confirmed (the client was added) or rejected.
class InstallationReport {
  final int id;
  final String code;

  /// submitted, confirmed or rejected.
  final String status;
  final String statusLabel;
  final String clientName;
  final String contactNumber;
  final String barangay;
  final String address;
  final String planName;
  final String paymentModeLabel;
  final String napLabel;
  final String coordinates;
  final String submittedAt;
  final String? adminRemarks;
  final String? clientCode;
  final List<TakenItem> taken;
  final List<ReportReturn> returns;

  const InstallationReport({
    required this.id,
    required this.code,
    required this.status,
    required this.statusLabel,
    required this.clientName,
    required this.contactNumber,
    required this.barangay,
    required this.address,
    required this.planName,
    required this.paymentModeLabel,
    required this.napLabel,
    required this.coordinates,
    required this.submittedAt,
    this.adminRemarks,
    this.clientCode,
    this.taken = const [],
    this.returns = const [],
  });

  factory InstallationReport.fromJson(Map<String, dynamic> json) {
    final box = _textOrNull(json['nap_box_name']);
    return InstallationReport(
      id: _int(json['id']),
      code: _text(json['code']),
      status: _text(json['status']),
      statusLabel: _text(json['status_label']),
      clientName: _text(json['client_name']),
      contactNumber: _text(json['contact_number']),
      barangay: _text(json['barangay_name']),
      address: _text(json['exact_address']),
      planName: _text(json['plan_name']),
      paymentModeLabel: _text(json['payment_mode_label']),
      napLabel: box == null ? '' : '$box · Port ${_int(json['port_number'])}',
      coordinates: _text(json['coordinates']),
      submittedAt: _text(json['submitted_at']),
      adminRemarks: _textOrNull(json['admin_remarks']),
      clientCode: _textOrNull(json['client_code']),
      taken: _rows(json['taken']).map(TakenItem.fromJson).toList(),
      returns: _rows(json['returns']).map(ReportReturn.fromJson).toList(),
    );
  }

  /// What the status chip shows with [StatusChip.forStatus].
  String get chipStatus => status == 'submitted'
      ? 'pending'
      : (status == 'confirmed' ? 'approved' : 'denied');
}

/// Where a barangay is on the map, so the coordinates of a report fill in by themselves. [precision] is "barangay" or, when the map
/// has no such barangay, "town".
class PlaceLocation {
  final bool found;
  final String coordinates;
  final String label;
  final String precision;

  /// The map could not be asked right now (so there is nothing to say about the place).
  final bool failed;

  const PlaceLocation({
    this.found = false,
    this.coordinates = '',
    this.label = '',
    this.precision = '',
    this.failed = false,
  });

  factory PlaceLocation.fromJson(Map<String, dynamic> json) => PlaceLocation(
    found: json['found'] == true,
    coordinates: _text(json['coordinates']),
    label: _text(json['label']),
    precision: _text(json['precision']),
    failed: json['error'] == true,
  );

  /// What to tell the person under the coordinates.
  String get note => precision == 'town'
      ? 'Filled in from $label (the barangay is not on the map, so this is the town). Choose the NAP box or paste the exact spot from Google Maps.'
      : 'Filled in from $label. It is near the client, not exact: choose the NAP box or paste the exact spot from Google Maps.';
}
