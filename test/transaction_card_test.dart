import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jftech/models/models.dart';
import 'package:jftech/widgets/transaction_card.dart';

void main() {
  testWidgets('an approved request shows who approved it and when; a waiting one does not', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            TransactionCard(
              entry: TransactionEntry.fromJson({
                'kind': 'item_out',
                'id': 174,
                'code': '#174',
                'title': 'Item Out',
                'subtitle': 'LAN Connector',
                'detail': 'Qty 5',
                'status': 'approved',
                'status_label': 'Approved',
                'occurred_at': '2026-10-14 09:24:00',
                'decided_at': '2026-10-14 13:18:00',
                'decided_by': 'Maria Santos',
              }),
            ),
            TransactionCard(
              entry: TransactionEntry.fromJson({
                'kind': 'item_return',
                'id': 175,
                'code': '#175',
                'title': 'Item Return',
                'subtitle': 'Pigtail',
                'detail': 'Qty 2',
                'status': 'pending',
                'status_label': 'Pending',
                'occurred_at': '2026-10-27 15:00:00',
              }),
            ),
          ],
        ),
      ),
    ));

    expect(find.text('LAN Connector'), findsOneWidget);
    expect(find.textContaining('Approved by Maria Santos'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('Pending by'), findsNothing);
  });
}
