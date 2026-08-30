import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collegesplit/screens/ledger_screen.dart';
import 'package:collegesplit/services/expense_service.dart';

/// Double that returns a canned Ledger and records the settled counterparty,
/// then returns an updated Ledger with that counterparty removed.
class _FakeExpenseService extends ExpenseService {
  _FakeExpenseService({this.ledger});

  Ledger? ledger;
  String? settledContactId;

  @override
  Future<Ledger> fetchLedger() async => ledger!;

  @override
  Future<Ledger> settleCounterparty(String contactId) async {
    settledContactId = contactId;
    ledger = Ledger(
      entries: ledger!.entries
          .where((e) => e.contactId != contactId)
          .toList(),
      totalOwedToUserPaise: ledger!.totalOwedToUserPaise - 6000,
      totalUserOwesPaise: ledger!.totalUserOwesPaise,
    );
    return ledger!;
  }
}

void main() {
  testWidgets(
      'Settle on a counterparty Balance shows a confirmation and zeroes it',
      (tester) async {
    final service = _FakeExpenseService(
      ledger: const Ledger(
        entries: [
          // Alice is a remembered Contact → can be settled.
          LedgerEntry(counterparty: 'Alice', balancePaise: 6000, contactId: 'c1'),
          // Bob is ephemeral → no contactId → no Settle action.
          LedgerEntry(counterparty: 'Bob', balancePaise: 5000),
        ],
        totalOwedToUserPaise: 11000,
        totalUserOwesPaise: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LedgerScreen(service: service))),
    );
    await tester.pumpAndSettle();

    // Both counterparties render; only Alice has a Settle button.
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(
      find.byTooltip('Settle balance with Alice'),
      findsOneWidget,
    );
    expect(find.byTooltip('Settle balance with Bob'), findsNothing);

    // Confirm flow first: cancelling leaves the Balance untouched.
    await tester.tap(find.byTooltip('Settle balance with Alice'));
    await tester.pumpAndSettle();
    expect(find.text('Settle balance with Alice?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.settledContactId, isNull);
    expect(find.text('Alice'), findsOneWidget);

    // Tapping Settle records the contact and zeroes (drops) the Balance.
    await tester.tap(find.byTooltip('Settle balance with Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settle'));
    await tester.pumpAndSettle();

    expect(service.settledContactId, 'c1');
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
  });
}
