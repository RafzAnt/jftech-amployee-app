import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jftech/main.dart';

void main() {
  testWidgets('JFTECH app shows the splash and then the login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const JFTechApp());

    // The splash screen renders first.
    expect(find.text('JFTECH'), findsOneWidget);
    expect(find.text('CONNECTING COMMUNITIES'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Nobody is signed in, so the login follows.
    expect(find.text('Employee Login'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2), reason: 'the username and the password');
    expect(find.text('Login'), findsOneWidget);
  });
}
