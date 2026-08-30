import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collegesplit/screens/add_expense_screen.dart';
import 'package:collegesplit/services/device_contacts.dart';
import 'package:collegesplit/services/expense_service.dart';

/// Fixture-backed device contact list for tests (ticket 06).
class _FakeDeviceContacts implements DeviceContacts {
  _FakeDeviceContacts({required this.phones, this.granted = true});

  /// Normalized name -> phone number.
  final Map<String, String> phones;
  bool granted;
  int requests = 0;

  @override
  Future<bool> requestPermission() async {
    requests++;
    return granted;
  }

  @override
  Future<String?> lookupPhone(String name) async =>
      phones[name.trim().toLowerCase()];
}

class _FakeExpenseService extends ExpenseService {
  int? capturedAmountPaise;
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
    capturedParticipants = participants;
    return Expense(
      id: 'e1',
      amountPaise: amountPaise,
      category: category,
      payerName: 'You',
      isUserPayer: true,
      splitMethod: splitMethod,
      createdAt: DateTime(2026, 8, 30),
      participants: participants
          .map(
            (p) => ExpenseParticipant(name: p.name, sharePaise: amountPaise),
          )
          .toList(),
    );
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

void main() {
  group('device-contacts auto-suggest (ticket 06)', () {
    testWidgets(
        'a typed name matching a device contact auto-suggests its phone, '
        'and the User can override it', (tester) async {
      final service = _FakeExpenseService();
      final deviceContacts = _FakeDeviceContacts(
        granted: true,
        phones: {'alice': '+91 1111111111'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpenseScreen(
              service: service,
              onAdded: () {},
              deviceContacts: deviceContacts,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (₹)'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Name').first,
        'Alice',
      );

      // Fire the debounce timer, then flush the async lookup + setState.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('+91 1111111111'), findsOneWidget);

      // The auto-suggested number is still a normal field: the User can
      // override it before submitting (ticket 05 manual edit path).
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone (optional)').first,
        '999',
      );
      await _tapAddExpense(tester);

      expect(service.capturedAmountPaise, 10000);
      expect(service.capturedParticipants.first.phoneNumber, '999');
    });

    testWidgets('a spoken name prefill auto-suggests a phone on the edit screen',
        (tester) async {
      final service = _FakeExpenseService();
      final deviceContacts = _FakeDeviceContacts(
        granted: true,
        phones: {'alice': '+91 1111111111'},
      );
      const draft = VoiceDraft(
        transcript: 'I paid lunch with Alice.',
        amountPaise: 10000,
        category: ExpenseCategory.foodDrink,
        payerName: null,
        isUserPayer: true,
        splitMethod: SplitMethod.equal,
        participants: [VoiceDraftParticipant(name: 'Alice')],
        missingFields: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpenseScreen(
              service: service,
              onAdded: () {},
              draft: draft,
              deviceContacts: deviceContacts,
            ),
          ),
        ),
      );
      // initState fires the lookup; settle the async result.
      await tester.pump();
      await tester.pump();

      expect(find.text('+91 1111111111'), findsOneWidget);
    });

    testWidgets('denying contact permission never blocks manual entry',
        (tester) async {
      final service = _FakeExpenseService();
      final deviceContacts = _FakeDeviceContacts(
        granted: false,
        phones: {'alice': '+91 1111111111'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpenseScreen(
              service: service,
              onAdded: () {},
              deviceContacts: deviceContacts,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (₹)'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Name').first,
        'Alice',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      // Permission denied → no suggestion, but adding still works.
      expect(find.text('+91 1111111111'), findsNothing);
      await _tapAddExpense(tester);
      expect(service.capturedAmountPaise, 10000);
      // The same name can still be entered manually with its own phone.
      // (Manual path already proven in the first test, so just check the
      // Participant went through with no suggested number.)
      expect(service.capturedParticipants.first.phoneNumber, isNull);
    });
  });
}
