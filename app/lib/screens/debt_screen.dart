import 'package:flutter/material.dart';

import '../services/expense_service.dart';
import 'expense_history_screen.dart';
import 'voice_capture_screen.dart';

/// The landing tab: a hero showing what the User owes vs what is owed to them,
/// a "Capture Expense" CTA, and their Expense History nested below (ticket 08).
class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key, required this.service});

  final ExpenseService service;

  @override
  State<DebtScreen> createState() => DebtScreenState();
}

class DebtScreenState extends State<DebtScreen> {
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
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openVoiceCapture() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceCaptureScreen(
          service: widget.service,
          onConfirm: _refresh,
        ),
      ),
    );
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
    return Column(
      children: [
        _Hero(
          ledger: _ledger,
          loading: _loading,
          error: _error,
          onRetry: _refresh,
          onCapture: _openVoiceCapture,
        ),
        Expanded(
          child: ExpenseHistoryScreen(
            service: widget.service,
            onChanged: _refresh,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.ledger,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onCapture,
  });

  final Ledger? ledger;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your debts', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Column(
              children: [
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'They owe you',
                    amountPaise: ledger!.totalOwedToUserPaise,
                    color: Colors.green.shade700,
                    icon: Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'You owe',
                    amountPaise: ledger!.totalUserOwesPaise,
                    color: Colors.red.shade700,
                    icon: Icons.arrow_upward,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.mic),
            label: const Text('Capture Expense'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.amountPaise,
    required this.color,
    required this.icon,
  });

  final String label;
  final int amountPaise;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DebtScreenState._rupees(amountPaise),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
