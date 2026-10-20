import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jftech/screens/main_shell.dart';

void main() {
  testWidgets('after login the Home shows three cards and only Home and Profile along the bottom', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'fullName': 'Juan Dela Cruz', 'position': 'Technician', 'branch': 'Balilihan'});

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Technician · Balilihan'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('NAP Box Monitoring'), findsOneWidget);
    expect(find.text('Installation & repair'), findsNothing, reason: 'the work requests are behind the bell and the Profile');

    // The bottom bar has two places, not one for every part of the app.
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Home')), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Profile')), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomNavigationBar), matching: find.byType(BottomNavigationBarItem)), findsNothing);
    final bar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bar.items, hasLength(2));
  });

  testWidgets('a card opens its own page with a back arrow, and the Profile holds the rest', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'fullName': 'Juan Dela Cruz', 'position': 'Technician', 'branch': 'Balilihan'});

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    await tester.tap(find.text('NAP Box Monitoring'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('NAP Box Monitoring')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('My work requests'), findsOneWidget);
    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('Server settings'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });
}
