import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jftech/widgets/scan_line.dart';

void main() {
  Future<AnimationController> pumpLine(WidgetTester tester) async {
    final controller = AnimationController(vsync: const TestVSync(), duration: const Duration(seconds: 2));
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 260, height: 260, child: ScanLine(animation: controller)),
        ),
      ),
    );
    return controller;
  }

  // The line is the thin Positioned: the glow behind it is the tall one.
  double lineTop(WidgetTester tester) {
    final lines = tester.widgetList<Positioned>(find.byType(Positioned)).where((p) => p.left == 12);
    expect(lines, hasLength(1));
    return lines.single.top!;
  }

  testWidgets('the line moves from the top of the frame to the bottom as the animation runs', (tester) async {
    final controller = await pumpLine(tester);

    controller.value = 0;
    await tester.pump();
    final atTop = lineTop(tester);

    controller.value = 0.5;
    await tester.pump();
    final inMiddle = lineTop(tester);

    controller.value = 1;
    await tester.pump();
    final atBottom = lineTop(tester);

    expect(atTop, lessThan(inMiddle));
    expect(inMiddle, lessThan(atBottom));
    expect(atTop, greaterThanOrEqualTo(0));
    expect(atBottom, lessThanOrEqualTo(260 - 3), reason: 'the line stays inside the frame');
    expect(inMiddle, closeTo((260 - 3) / 2, 4));
  });

  testWidgets('it never takes a tap away from the camera below it', (tester) async {
    await pumpLine(tester);

    expect(find.descendant(of: find.byType(ScanLine), matching: find.byType(IgnorePointer)), findsWidgets);
  });
}
