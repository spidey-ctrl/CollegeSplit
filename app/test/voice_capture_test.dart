import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collegesplit/screens/voice_capture_screen.dart';
import 'package:collegesplit/services/expense_service.dart';

/// Captures recorder interaction without touching platform channels.
class _FakeVoiceRecorder implements VoiceRecorder {
  int starts = 0;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<({Uint8List bytes, String mimeType})?> stop() async =>
      (bytes: Uint8List.fromList([1, 2, 3]), mimeType: 'audio/wav');

  @override
  Future<void> dispose() async {}
}

class _FakeExpenseService extends ExpenseService {
  _FakeExpenseService({this.draft, this.expense});

  VoiceDraft? draft;
  Expense? expense;
  Uint8List? capturedBytes;
  int? capturedAmountPaise;
  ExpenseCategory? capturedCategory;
  List<ExpenseParticipant> capturedParticipants = const [];

  @override
  Future<VoiceDraft> captureVoice({
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    capturedBytes = audioBytes;
    return draft!;
  }

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
    capturedParticipants = participants;
    return expense!;
  }
}

Expense _expense({int amountPaise = 12000}) => Expense(
      id: 'e1',
      amountPaise: amountPaise,
      category: ExpenseCategory.foodDrink,
      payerName: 'You',
      isUserPayer: true,
      splitMethod: SplitMethod.equal,
      createdAt: DateTime(2026, 8, 30),
      participants: const [
        ExpenseParticipant(name: 'Alice', sharePaise: 6000),
        ExpenseParticipant(name: 'Bob', sharePaise: 6000),
      ],
    );

VoiceDraft _fullDraft() => const VoiceDraft(
      transcript: 'I paid one hundred twenty rupees for lunch with Alice and Bob.',
      amountPaise: 12000,
      category: ExpenseCategory.foodDrink,
      payerName: null,
      isUserPayer: true,
      splitMethod: SplitMethod.equal,
      participants: [
        VoiceDraftParticipant(name: 'Alice'),
        VoiceDraftParticipant(name: 'Bob'),
      ],
      missingFields: [],
    );

VoiceDraft _missingAmountDraft() => const VoiceDraft(
      transcript: 'I paid for the cab but forgot the amount.',
      amountPaise: null,
      category: ExpenseCategory.transport,
      payerName: null,
      isUserPayer: true,
      splitMethod: SplitMethod.equal,
      participants: [
        VoiceDraftParticipant(name: 'Charlie'),
      ],
      missingFields: ['amount'],
    );

/// A Ratio draft with a stated Alex 30% and an inferred User 70% ("I'll cover
/// the rest"), as produced by the backend ratio-rest inference (ticket 04).
VoiceDraft _ratioDraft() => const VoiceDraft(
      transcript: 'Alex owes thirty percent, I will cover the rest of the taxi.',
      amountPaise: 5000,
      category: ExpenseCategory.transport,
      payerName: null,
      isUserPayer: true,
      splitMethod: SplitMethod.ratio,
      participants: [
        VoiceDraftParticipant(name: 'Alex', ratio: 30),
        VoiceDraftParticipant(name: 'You', ratio: 70, isUser: true),
      ],
      missingFields: [],
    );

Future<void> _driveRecording(
  WidgetTester tester,
  _FakeVoiceRecorder recorder,
) async {
  // The single IconButton acts as both the mic (start) and stop control.
  await tester.tap(find.byType(IconButton));
  await tester.pump();
  expect(recorder.starts, 1);
  await tester.tap(find.byType(IconButton));
  await tester.pumpAndSettle();
}

/// The confirm button sits below the fold on the default small test viewport,
/// so enlarge the viewport so the whole form (and button) is visible/tappable.
Future<void> _tapAddExpense(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add Expense'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('voice mic -> prefilled edit screen -> confirmed Equal expense',
      (tester) async {
    final service = _FakeExpenseService(
      draft: _fullDraft(),
      expense: _expense(),
    );
    final recorder = _FakeVoiceRecorder();
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceCaptureScreen(
          service: service,
          onConfirm: () {},
          recorder: recorder,
        ),
      ),
    );

    await _driveRecording(tester, recorder);

    // We should now be on the prefilled AddExpenseScreen.
    expect(find.text('Voice capture'), findsOneWidget); // banner title
    expect(find.widgetWithText(TextField, 'Amount (₹)'), findsOneWidget);
    expect(find.text('120.00'), findsOneWidget); // prefilled amount
    expect(find.widgetWithText(TextField, 'Alice'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Bob'), findsOneWidget);
    expect(service.capturedBytes, isNotNull);

    // Confirm the expense.
    await _tapAddExpense(tester);

    expect(service.capturedAmountPaise, 12000);
    expect(service.capturedCategory, ExpenseCategory.foodDrink);
  });

  testWidgets('a missing amount is left blank and highlighted, then confirmable',
      (tester) async {
    final service = _FakeExpenseService(
      draft: _missingAmountDraft(),
      expense: _expense(amountPaise: 5000),
    );
    final recorder = _FakeVoiceRecorder();
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceCaptureScreen(
          service: service,
          onConfirm: () {},
          recorder: recorder,
        ),
      ),
    );

    await _driveRecording(tester, recorder);

    // Amount is blank and its field is highlighted (error text shown).
    expect(find.text('Could not detect — please enter it'), findsOneWidget);

    // Submission is blocked until an amount is entered.
    await _tapAddExpense(tester);
    expect(service.capturedAmountPaise, isNull);

    // Enter the missing amount and confirm.
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (₹)'),
      '50',
    );
    await _tapAddExpense(tester);

    expect(service.capturedAmountPaise, 5000);
    expect(service.capturedCategory, ExpenseCategory.transport);
  });

  testWidgets('a Ratio-split draft prefills the edit screen and is editable',
      (tester) async {
    final service = _FakeExpenseService(
      draft: _ratioDraft(),
      expense: _expense(amountPaise: 5000),
    );
    final recorder = _FakeVoiceRecorder();
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceCaptureScreen(
          service: service,
          onConfirm: () {},
          recorder: recorder,
        ),
      ),
    );

    await _driveRecording(tester, recorder);

    // Ratio is active; the stated Alex share is editable, and the inferred
    // remainder is shown on the locked 'You' row (the User is the payer, not an
    // editable participant).
    expect(find.widgetWithText(TextField, 'Alex'), findsOneWidget);
    expect(find.textContaining('You paid — You'), findsOneWidget);
    expect(find.widgetWithText(TextField, '30'), findsOneWidget); // stated
    expect(find.textContaining('Your share: 70%'), findsOneWidget); // remainder

    // Editable: adjust Alex's share and confirm — the edited ratio is submitted.
    await tester.enterText(
      find.widgetWithText(TextField, '30'),
      '40',
    );
    await _tapAddExpense(tester);

    expect(service.capturedAmountPaise, 5000);
    // Only the other participants are submitted; the User is the payer.
    expect(service.capturedParticipants.map((p) => p.name), ['Alex']);
    final alex = service.capturedParticipants.single;
    expect(alex.ratio, 40);
    expect(alex.isUser, isFalse);
  });
}
