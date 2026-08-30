import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collegesplit/screens/expense_history_screen.dart';
import 'package:collegesplit/screens/ledger_screen.dart';
import 'package:collegesplit/services/expense_service.dart';

/// Double that list a settled Expense, records the edit, and returns a
/// freshly-derived reopened Ledger once the Expense is edited (ticket 08).
class _FakeExpenseService extends ExpenseService {
  _FakeExpenseService({required this.expenses});

  final List<Expense> expenses;
  String? updatedId;
  int? updatedAmountPaise;
  bool changed = false;
  Ledger ledger =
      const Ledger(entries: [], totalOwedToUserPaise: 0, totalUserOwesPaise: 0);

  @override
  Future<List<Expense>> listExpenses() async => expenses;

  @override
  Future<Expense> updateExpense({
    required String id,
    required int amountPaise,
    required ExpenseCategory category,
    required SplitMethod splitMethod,
    String? payerName,
    bool isUserPayer = true,
    List<ExpenseParticipant> participants = const [],
  }) async {
    updatedId = id;
    updatedAmountPaise = amountPaise;
    changed = true;
    // Editing a settled Expense reopens the Balance it belonged to.
    ledger = Ledger(
      entries: [
        LedgerEntry(
          counterparty: 'Sel',
          balancePaise: amountPaise,
          contactId: 'c1',
        ),
      ],
      totalOwedToUserPaise: amountPaise,
      totalUserOwesPaise: 0,
    );
    return Expense(
      id: id,
      amountPaise: amountPaise,
      category: category,
      payerName: 'You',
      isUserPayer: true,
      splitMethod: splitMethod,
      settled: false,
      createdAt: DateTime(2026, 8, 30),
      participants: participants,
    );
  }

  @override
  Future<Ledger> fetchLedger() async => ledger;
}

Expense _settledExpense() => Expense(
      id: 'e1',
      amountPaise: 5000,
      category: ExpenseCategory.foodDrink,
      payerName: 'You',
      isUserPayer: true,
      splitMethod: SplitMethod.equal,
      settled: true,
      createdAt: DateTime(2026, 8, 30),
      participants: const [ExpenseParticipant(name: 'Sel', sharePaise: 5000)],
    );

void main() {
  testWidgets(
      'editing a settled Expense from the history reopens its Balance',
      (tester) async {
    final service = _FakeExpenseService(expenses: [_settledExpense()]);

    // A tall viewport so the (ScrollView-based) edit form button is on-screen.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseHistoryScreen(
            service: service,
            onChanged: () => service.changed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The settled Expense shows up, marked as settled.
    expect(find.text('Settled'), findsOneWidget);
    expect(find.textContaining('₹50.00'), findsOneWidget);

    // Open the edit form, change the amount and save.
    await tester.tap(find.byTooltip('Edit Food & Drink expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Amount (₹)'), '60');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // The edit was sent to the backend for the right Expense/amount.
    expect(service.updatedId, 'e1');
    expect(service.updatedAmountPaise, 6000);
    // The onChanged hook fired, so the app refresh path is exercised.
    expect(service.changed, isTrue);

    // The Balance reopened: the freshly-derived Ledger includes Sel again.
    expect(service.ledger.entries.single.counterparty, 'Sel');
    expect(service.ledger.entries.single.balancePaise, 6000);

    // Seeing it live: the Ledger screen shows the reopened Balance.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LedgerScreen(service: service))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sel'), findsOneWidget);
    expect(find.text('₹60.00'), findsWidgets);
  });
}
