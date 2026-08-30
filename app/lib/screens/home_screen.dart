import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/expense_service.dart';
import 'add_expense_screen.dart';
import 'debt_screen.dart';
import 'ledger_screen.dart';
import 'voice_capture_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final Future<void> Function() onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final ExpenseService _expenseService = ExpenseService();
  final GlobalKey<DebtScreenState> _debtKey = GlobalKey<DebtScreenState>();
  final GlobalKey<LedgerScreenState> _ledgerKey =
      GlobalKey<LedgerScreenState>();

  void _refreshLedger() {
    _ledgerKey.currentState?.refresh();
  }

  void _refreshDebt() {
    _debtKey.currentState?.refresh();
  }

  void _openVoiceCapture() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceCaptureScreen(
          service: _expenseService,
          onConfirm: () {
            _refreshDebt();
            _refreshLedger();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CollegeSplit'),
        actions: [
          IconButton(
            tooltip: 'Add expense by voice',
            onPressed: _openVoiceCapture,
            icon: const Icon(Icons.mic),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await widget.onSignOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(child: Text(widget.user.displayName.characters.first)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          widget.user.email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                DebtScreen(key: _debtKey, service: _expenseService),
                AddExpenseScreen(
                  service: _expenseService,
                  onAdded: () {
                    _refreshDebt();
                    _refreshLedger();
                  },
                ),
                LedgerScreen(key: _ledgerKey, service: _expenseService),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.paid_outlined),
            label: 'Debt',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Expense',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Balance',
          ),
        ],
      ),
    );
  }
}
