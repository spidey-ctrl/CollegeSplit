import 'package:flutter/material.dart';

import '../services/api_error.dart';
import '../services/expense_service.dart';
import '../services/share_launcher.dart';

/// The User's private Ledger: who owes whom, as an aggregate Balance per
/// counterparty (computed from their Expenses and Splits — ticket 02).
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({
    super.key,
    required this.service,
    this.shareLauncher = const NativeShareLauncher(),
  });

  final ExpenseService service;

  /// Hand-off for the native share sheet when the User shares a Balance.
  final ShareLauncher shareLauncher;

  @override
  State<LedgerScreen> createState() => LedgerScreenState();
}

class LedgerScreenState extends State<LedgerScreen> {
  Ledger? _ledger;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ledger = await widget.service.fetchLedger();
      setState(() => _ledger = ledger);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  static String _rupees(int paise) {
    final sign = paise < 0 ? '-' : '';
    final abs = paise.abs();
    final rupees = abs ~/ 100;
    final fraction = (abs % 100).toString().padLeft(2, '0');
    return '$sign₹$rupees.$fraction';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    final ledger = _ledger!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(ledger: ledger),
          const SizedBox(height: 16),
          Text('Balances', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (ledger.entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No balances yet. Add an Expense and the money people '
                  'owe will show up here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...ledger.entries.map((e) => _entryTile(e)),
        ],
      ),
    );
  }

  Widget _entryTile(LedgerEntry entry) {
    final positive = entry.balancePaise >= 0;
    final color = positive ? Colors.green.shade700 : Colors.red.shade700;
    return ListTile(
      leading: CircleAvatar(child: Text(entry.counterparty.characters.first)),
      title: Text(entry.counterparty),
      subtitle: Text(positive ? 'owes you' : 'you owe'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _rupees(entry.balancePaise.abs()),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Share balance with ${entry.counterparty}',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(entry),
          ),
          if (entry.contactId != null)
            IconButton(
              tooltip: 'Settle balance with ${entry.counterparty}',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => _confirmAndSettle(entry),
            ),
        ],
      ),
    );
  }

  /// Fetches the Share payload for this Balance and hands it to the native
  /// share sheet (ticket 10). Pre-targets the counterparty's phone when on file.
  Future<void> _share(LedgerEntry entry) async {
    try {
      final payload =
          await widget.service.shareBalance(entry.counterparty);
      await widget.shareLauncher.launch(payload);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _confirmAndSettle(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Settle balance with ${entry.counterparty}?'),
        content: Text(
          'This records that you have been paid outside the app and zeroes '
          'your whole running balance with ${entry.counterparty}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Settle'),
          ),
        ],
      ),
    );
    if (confirmed != true || entry.contactId == null) return;

    try {
      final updated = await widget.service.settleCounterparty(entry.contactId!);
      setState(() {
        _ledger = updated;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('You are owed'),
                Text(
                  LedgerScreenState._rupees(ledger.totalOwedToUserPaise),
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('You owe'),
                Text(
                  LedgerScreenState._rupees(ledger.totalUserOwesPaise),
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net'),
                Text(
                  LedgerScreenState._rupees(
                    ledger.totalOwedToUserPaise - ledger.totalUserOwesPaise,
                  ),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
