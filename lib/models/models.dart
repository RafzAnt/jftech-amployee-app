// The things the server sends to the app, as plain Dart objects.

int _int(dynamic value, [int fallback = 0]) =>
    value == null ? fallback : (int.tryParse(value.toString()) ?? fallback);

int? _intOrNull(dynamic value) =>
    value == null ? null : int.tryParse(value.toString());

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
  return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
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

/// The person who is signed in, with what they did today.
class MeInfo {
  final int id;
  final String fullName;
  final String position;
  final String branch;
  final TodayAttendance today;
  final Map<String, int> workCounts;
  final int pendingInventory;

  const MeInfo({
    required this.id,
    required this.fullName,
    required this.position,
    required this.branch,
    required this.today,
    required this.workCounts,
    required this.pendingInventory,
  });

  factory MeInfo.fromJson(Map<String, dynamic> json) {
    final employee = Map<String, dynamic>.from(json['employee'] as Map? ?? {});
    final counts = <String, int>{};
    final rawCounts = json['work_requests'];
    if (rawCounts is Map) {
      rawCounts.forEach((key, value) => counts[key.toString()] = _int(value));
    }
    return MeInfo(
      id: _int(employee['id']),
      fullName: _text(employee['full_name'], 'Employee'),
      position: _text(employee['position']),
      branch: _text(employee['branch_name']),
      today: TodayAttendance.fromJson(Map<String, dynamic>.from(json['today'] as Map? ?? {})),
      workCounts: counts,
      pendingInventory: _int(json['pending_inventory_requests']),
    );
  }

  /// Requests that wait for the employee: returned for correction or approved (to do the work).
  int get needsAttention => (workCounts['returned'] ?? 0) + (workCounts['approved'] ?? 0);
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
    this.totalHours,
    this.checkedIn = false,
    this.onDuty = false,
  });

  factory TodayAttendance.fromJson(Map<String, dynamic> json) => TodayAttendance(
        checkInTime: _textOrNull(json['check_in_time']),
        morningIn: _textOrNull(json['morning_time_in']),
        morningOut: _textOrNull(json['morning_time_out']),
        afternoonIn: _textOrNull(json['afternoon_time_in']),
        afternoonOut: _textOrNull(json['afternoon_time_out']),
        overtimeIn: _textOrNull(json['overtime_time_in']),
        overtimeOut: _textOrNull(json['overtime_time_out']),
        overtimeMinutes: _int(json['overtime_minutes']),
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
    if (seconds == 0 && totalHours != null) seconds = (totalHours! * 3600).round();
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  /// The overtime has been started and not ended yet.
  bool get overtimeRunning => overtimeIn != null && overtimeOut == null;

  /// The overtime of the day as "1h 30m", or empty when there is none.
  String get overtimeLabel {
    if (overtimeIn == null) return '';
    final minutes = overtimeRunning ? _span(overtimeIn, null, DateTime.now()) ~/ 60 : overtimeMinutes;
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  int _span(String? timeIn, String? timeOut, DateTime now) {
    final start = _secondsOfDay(timeIn);
    if (start == null) return 0;
    final end = _secondsOfDay(timeOut) ?? (now.hour * 3600 + now.minute * 60 + now.second);
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
  /// available, occupied, reserved or faulty.
  final String status;
  final String? clientName;
  final String? clientCode;
  final String? reservedBy;

  const NapPort({
    required this.id,
    required this.number,
    required this.status,
    this.clientName,
    this.clientCode,
    this.reservedBy,
  });

  factory NapPort.fromJson(Map<String, dynamic> json) => NapPort(
        id: _int(json['id']),
        number: _int(json['port_number']),
        status: _text(json['status'], 'available'),
        clientName: _textOrNull(json['client_name']),
        clientCode: _textOrNull(json['client_code']),
        reservedBy: _textOrNull(json['reserved_by']),
      );

  String get statusLabel => status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1);
}

/// One stock transaction that belongs to a NAP box: the unit taken from the stock when it was installed, and the materials
/// the jobs on its ports used.
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

  factory NapInventoryEntry.fromJson(Map<String, dynamic> json) => NapInventoryEntry(
        occurredAt: _text(json['occurred_at']),
        itemName: _text(json['item_name']),
        typeLabel: _text(json['type_label']),
        quantityChange: _int(json['quantity_change']),
        employeeName: _textOrNull(json['employee_name']),
        clientName: _textOrNull(json['client_name']),
        clientCode: _textOrNull(json['client_code']),
        remarks: _textOrNull(json['remarks']),
      );

  /// "Out 1", "In 2", or empty when the line only records where items went (used or damaged on a job).
  String get quantityLabel => quantityChange == 0 ? '' : '${quantityChange < 0 ? 'Out' : 'In'} ${quantityChange.abs()}';

  /// "Ana Reyes · JFT-1", or empty.
  String get clientLabel => clientName == null ? '' : (clientCode == null ? clientName! : '$clientName · $clientCode');
}

class NapBox {
  final int id;
  final String name;
  final String barangay;
  final String location;
  final int totalPorts;
  final int occupiedPorts;
  final int reservedPorts;
  final int faultyPorts;
  final int availablePorts;
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
    required this.reservedPorts,
    required this.faultyPorts,
    required this.availablePorts,
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
        reservedPorts: _int(json['reserved_ports']),
        faultyPorts: _int(json['faulty_ports']),
        availablePorts: _int(json['available_ports']),
        ports: _rows(json['ports']).map(NapPort.fromJson).toList(),
        inventoryUsed: _rows(json['inventory_used']).map(NapInventoryEntry.fromJson).toList(),
        hasPhoto: json['has_photo'] == true,
        photoVersion: _textOrNull(json['photo_version']),
      );

  bool get isFull => availablePorts == 0;
}

class ClientSummary {
  final int id;
  final String code;
  final String name;
  final String phone;
  final String barangay;
  final String address;
  final String? napBoxName;
  final int? napPortNumber;

  const ClientSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    required this.barangay,
    required this.address,
    this.napBoxName,
    this.napPortNumber,
  });

  factory ClientSummary.fromJson(Map<String, dynamic> json) => ClientSummary(
        id: _int(json['id']),
        code: _text(json['client_code']),
        name: _text(json['full_name']),
        phone: _text(json['contact_number']),
        barangay: _text(json['barangay']),
        address: _text(json['address']),
        napBoxName: _textOrNull(json['nap_box_name']),
        napPortNumber: _intOrNull(json['nap_port_number']),
      );

  bool get isConnected => napBoxName != null;
}

class WorkMaterial {
  final int? inventoryId;
  final String itemName;
  final int used;
  final int returned;
  final int damaged;

  const WorkMaterial({
    required this.inventoryId,
    required this.itemName,
    required this.used,
    required this.returned,
    required this.damaged,
  });

  factory WorkMaterial.fromJson(Map<String, dynamic> json) => WorkMaterial(
        inventoryId: _intOrNull(json['inventory_id']),
        itemName: _text(json['item_name']),
        used: _int(json['used_quantity']),
        returned: _int(json['returned_quantity']),
        damaged: _int(json['damaged_quantity']),
      );
}

class WorkRequest {
  final int id;
  final String code;
  final String workType;
  final String status;
  final String statusLabel;
  final int? clientId;
  final bool isNewClient;
  final String clientName;
  final String clientPhone;
  final String clientAddress;
  final String barangay;
  final String location;
  final String problemDetails;
  final int? napBoxId;
  final String? napBoxName;
  final int? napPortId;
  final int? napPortNumber;
  final int? actualNapBoxId;
  final String? actualNapBoxName;
  final int? actualNapPortId;
  final int? actualNapPortNumber;
  final String completionNotes;
  final String adminRemarks;
  final String createdAt;
  final List<WorkMaterial> materials;

  const WorkRequest({
    required this.id,
    required this.code,
    required this.workType,
    required this.status,
    required this.statusLabel,
    required this.clientId,
    required this.isNewClient,
    required this.clientName,
    required this.clientPhone,
    required this.clientAddress,
    required this.barangay,
    required this.location,
    required this.problemDetails,
    required this.napBoxId,
    required this.napBoxName,
    required this.napPortId,
    required this.napPortNumber,
    required this.actualNapBoxId,
    required this.actualNapBoxName,
    required this.actualNapPortId,
    required this.actualNapPortNumber,
    required this.completionNotes,
    required this.adminRemarks,
    required this.createdAt,
    required this.materials,
  });

  factory WorkRequest.fromJson(Map<String, dynamic> json) => WorkRequest(
        id: _int(json['id']),
        code: _text(json['request_code']),
        workType: _text(json['work_type'], 'installation'),
        status: _text(json['status']),
        statusLabel: _text(json['status_label']),
        clientId: _intOrNull(json['client_id']),
        isNewClient: json['is_new_client'] == true,
        clientName: _text(json['client_name']),
        clientPhone: _text(json['client_phone']),
        clientAddress: _text(json['client_address']),
        barangay: _text(json['barangay_name']),
        location: _text(json['location']),
        problemDetails: _text(json['problem_details']),
        napBoxId: _intOrNull(json['nap_box_id']),
        napBoxName: _textOrNull(json['nap_box_name']),
        napPortId: _intOrNull(json['nap_port_id']),
        napPortNumber: _intOrNull(json['nap_port_number']),
        actualNapBoxId: _intOrNull(json['actual_nap_box_id']),
        actualNapBoxName: _textOrNull(json['actual_nap_box_name']),
        actualNapPortId: _intOrNull(json['actual_nap_port_id']),
        actualNapPortNumber: _intOrNull(json['actual_nap_port_number']),
        completionNotes: _text(json['completion_notes']),
        adminRemarks: _text(json['admin_remarks']),
        createdAt: _text(json['created_at']),
        materials: _rows(json['materials']).map(WorkMaterial.fromJson).toList(),
      );

  bool get isInstallation => workType == 'installation';
  String get typeLabel => isInstallation ? 'Installation' : 'Repair';

  /// "NAP-02 · Port 3", or empty when no port is involved.
  String get napLabel {
    final name = actualNapBoxName ?? napBoxName;
    final port = actualNapPortNumber ?? napPortNumber;
    if (name == null) return '';
    return port == null ? name : '$name · Port $port';
  }

  bool get canEdit => status == 'returned';
  bool get canCancel => status == 'pending_approval' || status == 'returned';
  bool get canReport => status == 'approved';
}

/// One line of the transaction history: an item out, an item return, an installation or a repair.
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
  });

  factory TransactionEntry.fromJson(Map<String, dynamic> json) => TransactionEntry(
        kind: _text(json['kind']),
        id: _int(json['id']),
        code: _text(json['code']),
        title: _text(json['title']),
        subtitle: _text(json['subtitle']),
        detail: _text(json['detail']),
        status: _text(json['status']),
        statusLabel: _text(json['status_label']),
        occurredAt: _text(json['occurred_at']),
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
        statusMorning: _text(json['status_morning']),
        statusAfternoon: _text(json['status_afternoon']),
        totalHours: _doubleOrNull(json['total_hours']),
        branch: _text(json['branch_name']),
      );
}
