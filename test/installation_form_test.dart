import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jftech/models/models.dart';
import 'package:jftech/screens/installation_form_screen.dart';
import 'package:jftech/screens/inventory_screen.dart';

const _options = InstallationOptions(
  barangays: ['Boctol', 'Cabad'],
  plans: [InstallationPlan(id: 1, name: 'Starter', speedMbps: 100, monthlyPrice: 999)],
  paymentModes: [ChoiceOption(value: 'cash', label: 'Cash'), ChoiceOption(value: 'gcash', label: 'GCash')],
  taken: [TakenItem(id: 10, itemName: 'Router', quantity: 3, approvedAt: '2026-10-28 09:00:00')],
);

Widget _form() => const MaterialApp(
      home: InstallationFormScreen(
        initialOptions: _options,
        initialStock: [StockItem(id: 1, name: 'Router', category: 'Network', available: 7, quantity: 7)],
      ),
    );

/// A tall screen, so the whole form is built at once and no test has to scroll to find a field.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the report asks for everything the admin needs, in the order of the work', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_form());

    for (final label in [
      'Items you took',
      '3 × Router',
      'Where it was installed',
      'Barangay *',
      'Google coordinates *',
      'NAP box and port',
      'Choose the barangay first to see its NAP boxes.',
      'Name *',
      'Contact number *',
      'Plan *',
      'Mode of payment (MOP) *',
      'IP address',
      'Facebook account',
      'Items you bring back',
      'Return item',
      'Send report',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('an incomplete report is not sent and says what is missing', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_form());

    await tester.tap(find.text('Send report'));
    await tester.pump();
    expect(find.text('Enter the name of the client.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Juan Dela Cruz'), 'Gina Mora');
    await tester.enterText(find.widgetWithText(TextField, '09171234567'), '0918');
    await tester.tap(find.text('Send report'));
    await tester.pump();
    expect(find.text('The contact number must have 11 digits, for example 09171234567.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '09171234567'), '09181234567');
    await tester.tap(find.text('Send report'));
    await tester.pump();
    expect(find.text('Choose the barangay.'), findsOneWidget);
  });

  testWidgets('choosing the barangay asks where it is; the coordinates stay the person\'s own once typed', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_form());

    // Nothing is filled in yet and the box says it will be.
    expect(find.textContaining('Fills in by itself from the barangay and the NAP box'), findsOneWidget);

    await tester.tap(find.text('Select barangay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boctol').last);
    await tester.pumpAndSettle();

    // The test has no server to ask, so the form says so instead of leaving the person guessing.
    expect(find.text('The map could not be asked now. Paste the coordinates from Google Maps.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '9.6541, 124.1234'), '9.7, 124.1');
    await tester.pump();
    expect(find.text('The map could not be asked now. Paste the coordinates from Google Maps.'), findsNothing, reason: 'typing gives the box back to the person');
    expect(find.textContaining('Fills in by itself'), findsOneWidget);
  });

  testWidgets('the Inventory page has an Installation tab next to Item Out and Item Return', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: InventoryScreen())));
    await tester.pump();

    expect(find.text('Item Out'), findsOneWidget);
    expect(find.text('Item Return'), findsOneWidget);
    expect(find.text('Installation'), findsOneWidget);
  });
}
