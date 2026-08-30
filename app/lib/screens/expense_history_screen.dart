import 'package:flutter/material.dart';

import '../services/expense_service.dart';
import 'add_expense_screen.dart';

/// A history/list view of a User's past Expenses (ticket 08). Each Expense —
/// settled or not — can be edited or deleted from here; editing or deleting a
/// settled one reopens the Balance it belonged to.
class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({
    super.key,
    required this.service,
    this.onChanged,
  });

  final ExpenseService service;

  /// Called after an edit/delete so a dependent view (e.g. the Ledger) can
  /// refresh, since reopening a settled Balance changes it.
  final VoidCallback? onChanged;

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  List<Expense>? _expenses;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final expenses = await widget.service.listExpenses();
      setState(() => _expenses = expenses);
    }       catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  static String _rupees(int paise) {
    final rupees = paise ~/ 100;
    final fraction = (paise % 100).toString().padLeft(2, '0');
    return '₹$rupees.$fraction';
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

    final expenses = _expenses!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        children: [
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No Expenses yet. Add one and it will show up here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...expenses.map((e) => _expenseTile(e)),
        ],
      ),
    );
  }

  Widget _expenseTile(Expense expense) {
    final participantNames = expense.participants
        .map((p) => p.name)
        .where((n) => n.isNotEmpty)
        .join(', ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(expense.category.label.characters.first)),
        title: Text(
          '${_rupees(expense.amountPaise)} · ${expense.category.label}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          expense.participants.isEmpty
              ? expense.payerName
              : '$participantNames · paid by ${expense.payerName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expense.settled)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Settled',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Edit ${expense.category.label} expense',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(expense),
            ),
            IconButton(
              tooltip: 'Delete ${expense.category.label} expense',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(expense),
            ),
          ],
        ),
        onTap: () => _edit(expense),
      ),
    );
  }

  Future<void> _edit(Expense expense) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Edit expense')),
          // AddExpenseScreen has no Scaffold of its own (it lives nested in
          // the Home tab), so wrap it for standalone use as a route.
          body: AddExpenseScreen(
            service: widget.service,
            existingExpense: expense,
            onAdded: widget.onChanged,
          ),
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this ${expense.category.label} expense?'),
        content: Text(
          'This removes the ${_rupees(expense.amountPaise)} expense'
          '${expense.settled ? ' and reopens the Balance it was settled with' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.service.deleteExpense(expense.id);
      widget.onChanged?.call();
      await _refresh();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }
}
