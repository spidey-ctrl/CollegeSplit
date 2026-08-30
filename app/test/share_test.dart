import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collegesplit/screens/expense_history_screen.dart';
import 'package:collegesplit/screens/ledger_screen.dart';
import 'package:collegesplit/services/expense_service.dart';
import 'package:collegesplit/services/share_launcher.dart';

/// Double that serves canned Share payloads and records the requests.
class _FakeExpenseService extends ExpenseService {
  _FakeExpenseService({
    this.expenses = const [],
    this.ledger,
    this.expensePayload,
    this.balancePayload,
  });

  List<Expense> expenses;
  Ledger? ledger;
  String? sharedExpenseId;
  String? sharedBalanceCounterparty;
  SharePayload? expensePayload;
  SharePayload? balancePayload;

  @override
  Future<List<Expense>> listExpenses() async => expenses;

  @override
  Future<Ledger> fetchLedger() async => ledger!;

  @override
  Future<SharePayload> shareExpense(String expenseId) async {
    sharedExpenseId = expenseId;
    return expensePayload ?? SharePayload(text: '', target: ShareTarget.none());
  }

  @override
  Future<SharePayload> shareBalance(String counterparty) async {
    sharedBalanceCounterparty = counterparty;
    return balancePayload ?? SharePayload(text: '', target: ShareTarget.none());
  }
}

/// Records every payload handed to the native share sheet.
class _RecordingShareLauncher implements ShareLauncher {
  final List<SharePayload> launched = [];

  @override
  Future<void> launch(SharePayload payload) async {
    launched.add(payload);
  }
}

Expense _expense({String id = 'e1', String participant = 'Dana'}) => Expense(
      id: id,
      amountPaise: 6000,
      category: ExpenseCategory.foodDrink,
      payerName: 'You',
      isUserPayer: true,
      splitMethod: SplitMethod.equal,
      createdAt: DateTime(2026, 8, 30),
      participants: [ExpenseParticipant(name: participant, sharePaise: 6000)],
    );

SharePayload _phonePayload() => SharePayload(
      text: 'Dana owes you ₹60.00\n— CollegeSplit',
      target: const ShareTarget(
        kind: ShareTargetKind.phone,
        phoneNumber: '+91-9999999999',
        deepLinkUrl: 'https://wa.me/919999999999?text=hi',
      ),
    );

void main() {
  Future<void> pumpHistory(WidgetTester tester, _FakeExpenseService service,
      _RecordingShareLauncher launcher) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseHistoryScreen(
            service: service,
            shareLauncher: launcher,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Sharing an Expense with a phone on file hands the launcher a '
      'pre-targeted payload', (tester) async {
    final service = _FakeExpenseService(
      expenses: [_expense()],
      expensePayload: _phonePayload(),
    );
    final launcher = _RecordingShareLauncher();
    await pumpHistory(tester, service, launcher);

    await tester.tap(find.byTooltip('Share Food & Drink expense'));
    await tester.pumpAndSettle();

    expect(service.sharedExpenseId, 'e1');
    expect(launcher.launched, hasLength(1));
    expect(launcher.launched.single.target.kind, ShareTargetKind.phone);
    expect(launcher.launched.single.target.deepLinkUrl, isNotNull);
  });

  testWidgets(
      'Sharing an Expense with no phone on file opens a generic sheet',
      (tester) async {
    final service = _FakeExpenseService(
      expenses: [_expense(participant: 'Evan')],
      expensePayload: SharePayload(
        text: '₹60.00 · Food & Drink\nPaid by You\nEvan: ₹60.00',
        target: ShareTarget.none(),
      ),
    );
    final launcher = _RecordingShareLauncher();
    await pumpHistory(tester, service, launcher);

    await tester.tap(find.byTooltip('Share Food & Drink expense'));
    await tester.pumpAndSettle();

    expect(launcher.launched, hasLength(1));
    expect(launcher.launched.single.target.kind, ShareTargetKind.none);
  });

  testWidgets('Sharing an aggregate Balance passes the counterparty to Share',
      (tester) async {
    final service = _FakeExpenseService(
      ledger: const Ledger(
        entries: [
          LedgerEntry(counterparty: 'Dana', balancePaise: 6000, contactId: 'c1'),
        ],
        totalOwedToUserPaise: 6000,
        totalUserOwesPaise: 0,
      ),
      balancePayload: _phonePayload(),
    );
    final launcher = _RecordingShareLauncher();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LedgerScreen(service: service, shareLauncher: launcher),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share balance with Dana'));
    await tester.pumpAndSettle();

    expect(service.sharedBalanceCounterparty, 'Dana');
    expect(launcher.launched, hasLength(1));
    expect(launcher.launched.single.target.kind, ShareTargetKind.phone);
  });
}
