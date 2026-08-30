import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collegesplit/screens/add_expense_screen.dart';
import 'package:collegesplit/screens/ledger_screen.dart';
import 'package:collegesplit/services/expense_service.dart';

/// Minimal double that records the create payload and returns a canned Expense.
class _FakeExpenseService extends ExpenseService {
  _FakeExpenseService({this.expense, this.ledger});

  Expense? expense;
  Ledger? ledger;
  int? capturedAmountPaise;
  ExpenseCategory? capturedCategory;
  SplitMethod? capturedSplitMethod;
  List<ExpenseParticipant> capturedParticipants = const [];

  @override
  Future<Expense> createExpense({
    required int amountPaise,
    required ExpenseCategory category,
    required SplitMethod splitMethod,
    String? payerName,
    bool isUserPayer = true,
    List<ExpenseParticipant> participants = const [],
  }) async {
    capturedAmountPaise = amountPaise;
    capturedCategory = category;
    capturedSplitMethod = splitMethod;
    capturedParticipants = participants;
    return expense!;
  }

  @override
  Future<Ledger> fetchLedger() async => ledger!;
}

Expense _expense() => Expense(
      id: 'e1',
      amountPaise: 12000,
      category: ExpenseCategory.foodDrink,
      payerName: 'You',
      isUserPayer: true,
      splitMethod: SplitMethod.equal,
      createdAt: DateTime(2026, 8, 30),
      participants: const [
        ExpenseParticipant(name: 'Alice', sharePaise: 4000),
        ExpenseParticipant(name: 'Bob', sharePaise: 4000),
        ExpenseParticipant(name: 'Carol', sharePaise: 4000),
      ],
    );

void main() {
  testWidgets('Add Expense form submits amount, category and participants',
      (tester) async {
    // A tall viewport so the submit button (below the participants fold) is
    // tappable, matching the other form tests in this suite.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeExpenseService(expense: _expense());
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AddExpenseScreen(service: service))),
    );

    await tester.enterText(
        find.widgetWithText(TextField, 'Amount (₹)'), '120');
    // Two participant rows exist by default; name the first two.
    await tester.enterText(
        find.widgetWithText(TextField, 'Name').first, 'Alice');
    await tester.enterText(
        find.widgetWithText(TextField, 'Name').at(1), 'Bob');

    await tester.tap(find.text('Add Expense'));
    await tester.pumpAndSettle();

    expect(service.capturedAmountPaise, 12000);
    expect(service.capturedCategory, ExpenseCategory.foodDrink);
    expect(service.capturedSplitMethod, SplitMethod.equal);
    expect(service.capturedParticipants.map((p) => p.name),
        ['Alice', 'Bob']);
  });

  testWidgets('Ledger screen shows the Balance each counterparty owes',
      (tester) async {
    final service = _FakeExpenseService(
      ledger: const Ledger(
        entries: [
          LedgerEntry(counterparty: 'Alice', balancePaise: 6000),
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

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('₹60.00'), findsOneWidget);
    expect(find.text('₹50.00'), findsOneWidget);
    // ₹110.00 appears in both the "You are owed" and "Net" summary rows.
    expect(find.text('₹110.00'), findsWidgets);
  });
}
