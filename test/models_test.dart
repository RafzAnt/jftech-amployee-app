import 'package:flutter_test/flutter_test.dart';

import 'package:jftech/models/models.dart';

void main() {
  historyTests();

  test('clockTime shows a 24 hour time the way people read it', () {
    expect(clockTime('08:05:00'), '8:05 AM');
    expect(clockTime('12:00:00'), '12:00 PM');
    expect(clockTime('00:30:00'), '12:30 AM');
    expect(clockTime('17:45:10'), '5:45 PM');
    expect(clockTime(null), '');
    expect(clockTime(''), '');
  });

  test("today's hours add the sessions and keep counting while on duty", () {
    const finished = TodayAttendance(
      morningIn: '08:00:00',
      morningOut: '12:00:00',
      afternoonIn: '13:00:00',
      afternoonOut: '14:30:00',
      checkedIn: true,
    );
    expect(finished.hoursLabel(DateTime(2026, 10, 17, 18)), '5h 30m');

    const onDuty = TodayAttendance(morningIn: '08:00:00', checkedIn: true, onDuty: true);
    expect(onDuty.hoursLabel(DateTime(2026, 10, 17, 10, 45)), '2h 45m');

    const notIn = TodayAttendance();
    expect(notIn.hoursLabel(DateTime(2026, 10, 17, 10)), '0h 0m');
  });

  test('the overtime of the day is read, counted in the hours, and shown while it runs', () {
    final finished = TodayAttendance.fromJson({
      'morning_time_in': '08:00:00',
      'morning_time_out': '12:00:00',
      'afternoon_time_in': '13:00:00',
      'afternoon_time_out': '17:00:00',
      'overtime_time_in': '17:05:00',
      'overtime_time_out': '18:35:00',
      'overtime_minutes': 90,
      'checked_in': true,
    });
    expect(finished.overtimeRunning, isFalse);
    expect(finished.overtimeMinutes, 90);
    expect(finished.overtimeLabel, '1h 30m');
    expect(finished.hoursLabel(DateTime(2026, 10, 17, 20)), '9h 30m');

    final running = TodayAttendance.fromJson({'overtime_time_in': '17:05:00', 'overtime_time_out': null, 'on_duty': true, 'checked_in': true});
    expect(running.overtimeRunning, isTrue);
    expect(running.hoursLabel(DateTime(2026, 10, 17, 18, 5)), '1h 0m');

    expect(const TodayAttendance().overtimeLabel, '');
  });

  test('the overtime from the afternoon time out is paid only from the minimum the server gives', () {
    // The afternoon ends at 17:00 and the time out at 17:40 is 40 minutes of overtime: noted, not paid.
    final short = TodayAttendance.fromJson({
      'afternoon_time_in': '13:00:00',
      'afternoon_time_out': '17:00:00',
      'overtime_time_in': '17:00:00',
      'overtime_time_out': '17:40:00',
      'overtime_minutes': 40,
      'overtime_minimum_minutes': 60,
      'checked_in': true,
    });
    expect(short.overtimeRunning, isFalse);
    expect(short.overtimeCounted, isFalse);
    expect(short.overtimeLabel, '0h 40m');
    expect(short.hoursLabel(DateTime(2026, 10, 28, 20)), '4h 40m');

    final paid = TodayAttendance.fromJson({'overtime_time_in': '17:00:00', 'overtime_time_out': '18:30:00', 'overtime_minutes': 90, 'overtime_minimum_minutes': 60});
    expect(paid.overtimeCounted, isTrue);

    // An older server does not say: an hour.
    expect(TodayAttendance.fromJson({'overtime_minutes': 59}).overtimeMinimumMinutes, 60);
    expect(TodayAttendance.fromJson({'overtime_minutes': 59}).overtimeCounted, isFalse);
    expect(TodayAttendance.fromJson({'overtime_minutes': 60}).overtimeCounted, isTrue);
    expect(TodayAttendance.fromJson({'overtime_minutes': 20, 'overtime_minimum_minutes': 15}).overtimeCounted, isTrue);
    expect(AttendanceSummary.fromJson({'overtime_minimum_minutes': 90}).overtimeMinimumMinutes, 90);
    expect(const AttendanceSummary().overtimeMinimumMinutes, 60);
  });

  test('a history day carries its overtime', () {
    final day = AttendanceDay.fromJson({'attendance_date': '2026-10-16', 'overtime_time_in': '17:00:00', 'overtime_time_out': '18:30:00', 'overtime_minutes': '90'});
    expect(day.overtimeIn, '17:00:00');
    expect(day.overtimeMinutes, 90);
    expect(AttendanceDay.fromJson({'attendance_date': '2026-10-16'}).overtimeIn, isNull);
  });

  test('the home information is read from the server answer', () {
    final me = MeInfo.fromJson({
      'success': true,
      'employee': {'id': 7, 'full_name': 'Juan Dela Cruz', 'position': 'Technician I', 'branch_name': 'Balilihan'},
      'today': {'checked_in': true, 'on_duty': true, 'check_in_time': '08:12:00', 'morning_time_in': '08:12:00'},
      'pending_inventory_requests': 4,
    });

    expect(me.fullName, 'Juan Dela Cruz');
    expect(me.branch, 'Balilihan');
    expect(me.today.onDuty, isTrue);
    expect(me.pendingInventory, 4);
  });

  test('a NAP box and its ports are read from the server answer', () {
    final box = NapBox.fromJson({
      'id': 2,
      'name': 'NAP-02',
      'barangay_name': 'Boctol',
      'location': 'Purok 2',
      'total_ports': 8,
      'occupied_ports': 5,
      'faulty_ports': 0,
      'available_ports': 3,
      'ports': [
        {'id': 11, 'port_number': 1, 'status': 'occupied', 'client_name': 'Ana Reyes', 'client_code': 'JFT-1'},
        {'id': 12, 'port_number': 2, 'status': 'available'},
      ],
    });

    expect(box.isFull, isFalse);
    expect(box.ports.length, 2);
    expect(box.ports.first.clientName, 'Ana Reyes');
    expect(box.ports.last.statusLabel, 'Available');

    final full = NapBox.fromJson({'id': 3, 'name': 'NAP-03', 'total_ports': 4, 'available_ports': 0});
    expect(full.isFull, isTrue);
  });

  test('a NAP box carries the inventory used on it', () {
    final box = NapBox.fromJson({
      'id': 1,
      'name': 'NAP-01',
      'barangay_name': 'Boctol',
      'total_ports': 8,
      'occupied_ports': 3,
      'available_ports': 5,
      'ports': [],
      'inventory_used': [
        {'occurred_at': '2026-10-19 09:30:00', 'item_name': 'NAP Box 8-port', 'type_label': 'NAP Box Installed', 'quantity_change': -1, 'remarks': 'NAP-01 installed at Boctol.'},
        {'occurred_at': '2026-10-19 11:00:00', 'item_name': 'Fiber Cable', 'type_label': 'Used on Job', 'quantity_change': 0, 'employee_name': 'Eli Santos', 'client_name': 'Nina Reyes', 'client_code': 'JFT-9'},
      ],
    });

    expect(box.inventoryUsed, hasLength(2));
    expect(box.inventoryUsed[0].quantityLabel, 'Out 1');
    expect(box.inventoryUsed[0].clientLabel, '');
    expect(box.inventoryUsed[1].quantityLabel, '', reason: 'used on a job only records where the items went');
    expect(box.inventoryUsed[1].clientLabel, 'Nina Reyes · JFT-9');
    expect(box.inventoryUsed[1].employeeName, 'Eli Santos');

    // The list of boxes has no inventory yet.
    expect(NapBox.fromJson({'id': 2, 'name': 'NAP-02'}).inventoryUsed, isEmpty);
  });

  test('a NAP box knows whether it has a photo', () {
    final withPhoto = NapBox.fromJson({'id': 1, 'name': 'NAP-01', 'has_photo': true, 'photo_version': '1760000000'});
    expect(withPhoto.hasPhoto, isTrue);
    expect(withPhoto.photoVersion, '1760000000');

    final without = NapBox.fromJson({'id': 2, 'name': 'NAP-02', 'has_photo': false, 'photo_version': null});
    expect(without.hasPhoto, isFalse);
    expect(without.photoVersion, isNull);
    expect(NapBox.fromJson({'id': 3, 'name': 'NAP-03'}).hasPhoto, isFalse);
  });

  test('a NAP port that another technician reported but the admin has not confirmed is reserved, not free', () {
    final free = NapPort.fromJson({'id': 1, 'port_number': 1, 'status': 'available', 'reserved': false});
    final reserved = NapPort.fromJson({'id': 2, 'port_number': 2, 'status': 'available', 'reserved': true});
    final used = NapPort.fromJson({'id': 3, 'port_number': 3, 'status': 'occupied', 'client_name': 'Ana Reyes', 'client_code': 'JFT-1'});

    expect(free.isFree, isTrue);
    expect(reserved.isFree, isFalse);
    expect(reserved.displayStatus, 'reserved');
    expect(reserved.statusLabel, 'Reserved');
    expect(used.isFree, isFalse);
    expect(used.clientName, 'Ana Reyes');
  });

  test('a NAP box carries where it hangs', () {
    final box = NapBox.fromJson({
      'id': 1,
      'name': 'NAP-01',
      'barangay_name': 'Boctol',
      'total_ports': 8,
      'available_ports': 5,
      'coordinates': '9.650000, 124.120000',
    });
    expect(box.coordinates, '9.650000, 124.120000');
    expect(NapBox.fromJson({'id': 2, 'name': 'NAP-02'}).coordinates, '');
  });

  test('the installation form options are read, with the items that wait for a report', () {
    final options = InstallationOptions.fromJson({
      'barangays': ['Boctol', 'Cabad'],
      'plans': [
        {'id': 1, 'plan_name': 'Starter', 'speed_mbps': 100, 'monthly_price': 999}
      ],
      'payment_modes': [
        {'value': 'cash', 'label': 'Cash'},
        {'value': 'gcash', 'label': 'GCash'}
      ],
      'taken': [
        {'id': 10, 'item_name': 'Router', 'quantity': 3, 'approved_at': '2026-10-28 09:00:00'}
      ],
    });

    expect(options.barangays, ['Boctol', 'Cabad']);
    expect(options.plans.single.label, contains('Starter (100 Mbps)'));
    expect(options.paymentModes.map((mode) => mode.value), ['cash', 'gcash']);
    expect(options.conditions, ['Good', 'Damaged', 'Defective'], reason: 'the usual conditions when the server sends none');
    expect(options.taken.single.itemName, 'Router');
    expect(options.taken.single.quantity, 3);
  });

  test('the report goes to the server with the NAP port, the coordinates and the items brought back', () {
    const draft = InstallationDraft(
      fullName: '  Gina Mora ',
      contactNumber: '09181234567',
      barangay: 'Boctol',
      address: 'Purok 3',
      planId: 1,
      paymentMode: 'gcash',
      coordinates: '9.6541, 124.1234',
      napPortId: 7,
      requestIds: [10],
      returns: [ReturnLine(inventoryId: 1, itemName: 'Router', quantity: 1, condition: 'Good')],
    );

    final json = draft.toJson();
    expect(json['full_name'], 'Gina Mora');
    expect(json['nap_port_id'], 7);
    expect(json['payment_mode'], 'gcash');
    expect(json['coordinates'], '9.6541, 124.1234');
    expect(json['request_ids'], [10]);
    expect(json['returns'], [
      {'inventory_id': 1, 'quantity': 1, 'item_condition': 'Good'}
    ]);
    expect(json['ip_address'], '');
  });

  test('a report shows where it is: waiting, confirmed with the client, or rejected with the admin\'s words', () {
    final waiting = InstallationReport.fromJson({
      'id': 1,
      'code': '#1',
      'status': 'submitted',
      'status_label': 'Waiting for admin',
      'client_name': 'Gina Mora',
      'nap_box_name': 'NAP-01',
      'port_number': 3,
      'taken': [
        {'id': 10, 'item_name': 'Router', 'quantity': 3}
      ],
      'returns': [
        {'item_name': 'Router', 'quantity': 1, 'accepted_quantity': null, 'item_condition': 'Good'}
      ],
    });
    expect(waiting.chipStatus, 'pending');
    expect(waiting.napLabel, 'NAP-01 · Port 3');
    expect(waiting.returns.single.acceptedQuantity, isNull);

    final confirmed = InstallationReport.fromJson({'id': 2, 'status': 'confirmed', 'client_code': 'JFT-2026-AB'});
    expect(confirmed.chipStatus, 'approved');
    expect(confirmed.clientCode, 'JFT-2026-AB');
    expect(confirmed.napLabel, '');

    final rejected = InstallationReport.fromJson({'id': 3, 'status': 'rejected', 'admin_remarks': 'Wrong port.'});
    expect(rejected.chipStatus, 'denied');
    expect(rejected.adminRemarks, 'Wrong port.');
  });

  test('Home knows how many approved installations wait for a report', () {
    final me = MeInfo.fromJson({
      'employee': {'id': 1, 'full_name': 'Eli Santos'},
      'today': <String, dynamic>{},
      'pending_inventory_requests': 0,
      'awaiting_installation_reports': 2,
    });
    expect(me.awaitingInstallationReports, 2);
    expect(MeInfo.fromJson({'employee': <String, dynamic>{}, 'today': <String, dynamic>{}}).awaitingInstallationReports, 0);
  });

  test('where a barangay is: found at the barangay, found only as the town, or not found', () {
    final barangay = PlaceLocation.fromJson({'found': true, 'coordinates': '9.768206, 123.993066', 'label': 'Boctol, Balilihan', 'precision': 'barangay'});
    expect(barangay.found, isTrue);
    expect(barangay.coordinates, '9.768206, 123.993066');
    expect(barangay.note, contains('Filled in from Boctol, Balilihan'));
    expect(barangay.note, contains('near the client, not exact'));

    final town = PlaceLocation.fromJson({'found': true, 'coordinates': '9.8033, 123.7961', 'label': 'Loon', 'precision': 'town'});
    expect(town.note, contains('the barangay is not on the map, so this is the town'));

    final missing = PlaceLocation.fromJson({'found': false});
    expect(missing.found, isFalse);
    expect(missing.failed, isFalse);
    expect(PlaceLocation.fromJson({'found': false, 'error': true}).failed, isTrue, reason: 'the map could not be asked');
  });
}

void historyTests() {
  test('durationLabel reads minutes the way people say them', () {
    expect(durationLabel(0), '0m');
    expect(durationLabel(-5), '0m');
    expect(durationLabel(45), '45m');
    expect(durationLabel(60), '1h');
    expect(durationLabel(135), '2h 15m');
  });

  test('a history day carries its late and undertime minutes and knows when it was a complete day', () {
    final complete = AttendanceDay.fromJson({
      'attendance_date': '2026-10-20',
      'morning_time_in': '08:05:00',
      'morning_time_out': '11:58:00',
      'afternoon_time_in': '13:04:00',
      'afternoon_time_out': '16:57:00',
      'status_morning': 'present',
      'status_afternoon': 'present',
      'late_minutes': 0,
      'undertime_minutes': 0,
      'total_hours': '7.77',
    });
    expect(complete.complete, isTrue);
    expect(complete.totalHours, 7.77);

    final early = AttendanceDay.fromJson({
      'attendance_date': '2026-10-21',
      'morning_time_in': '08:05:00',
      'afternoon_time_in': '13:04:00',
      'status_morning': 'present',
      'status_afternoon': 'present',
      'undertime_minutes': '45',
    });
    expect(early.undertimeMinutes, 45);
    expect(early.complete, isFalse, reason: 'leaving early is not a complete day');

    final late = AttendanceDay.fromJson({
      'attendance_date': '2026-10-22',
      'morning_time_in': '08:48:00',
      'afternoon_time_in': '13:04:00',
      'status_morning': 'late',
      'status_afternoon': 'present',
      'late_minutes': 48,
    });
    expect(late.lateMinutes, 48);
    expect(late.complete, isFalse);
  });

  test('the attendance summary is read as the server sends it', () {
    final summary = AttendanceSummary.fromJson({
      'days_recorded': 26,
      'days_worked': 24.5,
      'late_minutes': 48,
      'undertime_minutes': 45,
      'overtime_minutes': 190,
      'total_hours': 182.94,
      'absent_sessions': 2,
    });
    expect(summary.daysRecorded, 26);
    expect(summary.daysWorked, 24.5);
    expect(summary.overtimeMinutes, 190);
    expect(summary.totalHours, 182.94);
    expect(const AttendanceSummary().daysWorked, 0);
  });

  test('a transaction says who decided it and when, and nothing while it waits', () {
    final approved = TransactionEntry.fromJson({
      'kind': 'item_out',
      'id': 174,
      'status': 'approved',
      'status_label': 'Approved',
      'occurred_at': '2026-10-14 09:24:00',
      'decided_at': '2026-10-14 13:18:00',
      'decided_by': 'Maria Santos',
    });
    expect(approved.decidedBy, 'Maria Santos');
    expect(approved.decidedAt, '2026-10-14 13:18:00');

    final waiting = TransactionEntry.fromJson({'kind': 'item_out', 'id': 175, 'status': 'pending', 'decided_at': null, 'decided_by': null});
    expect(waiting.decidedAt, '');
    expect(waiting.decidedBy, '');
  });
}
