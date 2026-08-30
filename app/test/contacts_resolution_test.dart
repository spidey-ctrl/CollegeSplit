import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collegesplit/screens/add_expense_screen.dart';
import 'package:collegesplit/services/expense_service.dart';

/// Stateful fake whose `createExpense` resolves a Participant to a Contact only
/// once its name has been seen before — mirroring the backend rule that the 2nd
/// distinct use auto-creates and auto-links a Contact (ticket 05).
class _FakeExpenseService extends ExpenseService {
  final Map<String, int> _seen = {};
  int _call = 0;
  Expense? lastReturned;
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
    capturedParticipants = participants;
    _call++;
    final String name = participants.first.name;
    final int count = (_seen[name] ?? 0) + 1;
    _seen[name] = count;

    final match = count >= 2
        ? ParticipantMatch(
            kind: MatchKind.autoLinked,
            contactId: 'c-$name',
            contactName: name,
          )
        : null;

    lastReturned = Expense(
      id: 'e$_call',
      amountPaise: amountPaise,
      category: category,
      payerName: 'You',
      isUserPayer: true,
      splitMethod: splitMethod,
      createdAt: DateTime(2026, 8, 30),
      participants: [
        ExpenseParticipant(name: name, isUser: isUserPayer, contactMatch: match),
      ],
    );
    return lastReturned!;
  }
}

/// The Add Expense button sits below the fold on the default small test
/// viewport, so enlarge the viewport so the whole form is visible/tappable.
Future<void> _tapAddExpense(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add Expense'));
  await tester.pumpAndSettle();
}

/// Enters a name and phone into the first participant row.
Future<void> _enterFirstParticipant(
  WidgetTester tester,
  String name,
  String phone,
) async {
  await tester.enterText(find.widgetWithText(TextField, 'Name').first, name);
  await tester.enterText(
    find.widgetWithText(TextField, 'Phone (optional)').first,
    phone,
  );
}

void main() {
  testWidgets(
      'same name across two Expenses resolves to one Contact on the second entry',
      (tester) async {
    final service = _FakeExpenseService();

    Future<void> pumpAndFillFirstEntry() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpenseScreen(service: service, onAdded: () {}),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (₹)'),
        '100',
      );
      await _enterFirstParticipant(tester, 'Same', '+91-9000000001');
      await _tapAddExpense(tester);
    }

    // First Expense: the Participant "Same" carries a phone and is being seen
    // for the first time, so no Contact exists yet — no auto-link.
    await pumpAndFillFirstEntry();
    expect(service.capturedParticipants.first.phoneNumber, '+91-9000000001');
    expect(service.lastReturned!.participants.first.contactMatch, isNull);
    expect(find.textContaining('saved as contact'), findsNothing);

    // Second Expense: the same name+phone is entered again, so it resolves to
    // the one accumulated Contact (auto-linked) on this entry.
    await pumpAndFillFirstEntry();
    final match = service.lastReturned!.participants.first.contactMatch;
    expect(match, isNotNull);
    expect(match!.isAutoLinked, isTrue);
    expect(match.contactName, 'Same');
    expect(find.text('Same → saved as contact Same'), findsOneWidget);
  });
}
