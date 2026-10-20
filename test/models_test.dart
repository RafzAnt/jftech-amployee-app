import 'package:flutter_test/flutter_test.dart';

import 'package:jftech/models/models.dart';

void main() {
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
      'work_requests': {'pending_approval': 2, 'returned': 1, 'approved': 3, 'confirmed': 9},
      'pending_inventory_requests': 4,
    });

    expect(me.fullName, 'Juan Dela Cruz');
    expect(me.branch, 'Balilihan');
    expect(me.today.onDuty, isTrue);
    expect(me.pendingInventory, 4);
    expect(me.needsAttention, 4, reason: 'returned and approved wait for the employee');
  });

  test('a NAP box and its ports are read from the server answer', () {
    final box = NapBox.fromJson({
      'id': 2,
      'name': 'NAP-02',
      'barangay_name': 'Boctol',
      'location': 'Purok 2',
      'total_ports': 8,
      'occupied_ports': 5,
      'reserved_ports': 0,
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

  test('a work request knows what the employee may do with it', () {
    WorkRequest request(String status) => WorkRequest.fromJson({
          'id': 1,
          'request_code': 'WR-1',
          'work_type': 'installation',
          'status': status,
          'status_label': status,
          'is_new_client': true,
          'client_name': 'Nina Reyes',
          'nap_box_name': 'NAP-01',
          'nap_port_number': 3,
        });

    expect(request('returned').canEdit, isTrue);
    expect(request('returned').canCancel, isTrue);
    expect(request('pending_approval').canEdit, isFalse);
    expect(request('pending_approval').canCancel, isTrue);
    expect(request('approved').canReport, isTrue);
    expect(request('approved').canCancel, isFalse);
    expect(request('confirmed').canReport, isFalse);
    expect(request('approved').napLabel, 'NAP-01 · Port 3');
    expect(request('approved').typeLabel, 'Installation');
  });

  test('a report port beats the proposed one in the label', () {
    final request = WorkRequest.fromJson({
      'id': 1,
      'request_code': 'WR-1',
      'work_type': 'installation',
      'status': 'work_completed',
      'nap_box_name': 'NAP-01',
      'nap_port_number': 3,
      'actual_nap_box_name': 'NAP-02',
      'actual_nap_port_number': 5,
    });
    expect(request.napLabel, 'NAP-02 · Port 5');
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
}
