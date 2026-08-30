import 'package:flutter/material.dart';

import '../services/expense_service.dart';

/// Form to add an Expense — amount, Category, Split Method and Participants.
///
/// Used both for manual entry (ticket 02) and as the confirm/edit screen after a
/// voice capture (ticket 03), where [draft] prefills the fields the app
/// understood and [draft.missingFields] marks the ones it couldn't extract.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.service, this.onAdded, this.draft});

  final ExpenseService service;

  /// Called after an Expense is successfully created (e.g. to refresh a Ledger).
  final VoidCallback? onAdded;

  /// A voice-capture draft to prefill the form with (optional).
  final VoiceDraft? draft;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _ParticipantRow {
  _ParticipantRow();

  final TextEditingController name = TextEditingController();
  // Ratio weight, or Adhoc rupees amount, depending on the split method.
  final TextEditingController value = TextEditingController();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.foodDrink;
  SplitMethod _splitMethod = SplitMethod.equal;
  final List<_ParticipantRow> _participants = [];
  bool _busy = false;
  String? _error;
  String? _success;
  // Field names the voice capture couldn't confidently extract. These stay
  // blank and get a highlighted border until the User fills them in.
  final Set<String> _highlighted = {};

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft != null) {
      _splitMethod = SplitMethod.equal;
      if (draft.amountPaise != null) {
        _amountController.text = _paiseToRupees(draft.amountPaise!);
      }
      if (draft.category != null) {
        _category = draft.category!;
      }
      // One row per understood participant plus a trailing empty one.
      for (final p in draft.participants) {
        _participants.add(_ParticipantRow()..name.text = p.name);
      }
      _participants.add(_ParticipantRow());
      _highlighted.addAll(draft.missingFields);
    } else {
      _participants.add(_ParticipantRow());
      _participants.add(_ParticipantRow());
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (final p in _participants) {
      p.name.dispose();
      p.value.dispose();
    }
    super.dispose();
  }

  /// Parses a user-entered rupee amount (e.g. "120" or "120.50") into paise.
  int? _rupeesToPaise(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final re = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!re.hasMatch(t)) return null;
    final parts = t.split('.');
    final rupees = int.parse(parts[0]);
    final paise = parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return rupees * 100 + paise;
  }

  String _paiseToRupees(int paise) {
    final rupees = paise ~/ 100;
    final fraction = (paise % 100).toString().padLeft(2, '0');
    return '$rupees.$fraction';
  }

  Future<void> _submit() async {
    final amountPaise = _rupeesToPaise(_amountController.text);
    if (amountPaise == null || amountPaise <= 0) {
      setState(() => _error = 'Enter a valid amount greater than 0');
      return;
    }

    final cleanedNames = _participants
        .map((p) => p.name.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (_splitMethod != SplitMethod.equal && cleanedNames.isEmpty) {
      setState(() => _error = 'Add at least one Participant');
      return;
    }

    // Build participant inputs according to the chosen split method.
    final participants = <ExpenseParticipant>[];
    for (var i = 0; i < _participants.length; i++) {
      final row = _participants[i];
      final name = row.name.text.trim();
      if (name.isEmpty) continue;

      switch (_splitMethod) {
        case SplitMethod.equal:
          participants.add(ExpenseParticipant(name: name));
          break;
        case SplitMethod.ratio:
          final ratio = int.tryParse(row.value.text.trim());
          if (ratio == null || ratio <= 0) {
            setState(() => _error = 'Give each Participant a ratio weight > 0');
            return;
          }
          participants.add(ExpenseParticipant(name: name, ratio: ratio));
          break;
        case SplitMethod.adhoc:
          final share = _rupeesToPaise(row.value.text);
          if (share == null || share <= 0) {
            setState(() =>
                _error = 'Give each Participant an exact amount > 0');
            return;
          }
          participants.add(ExpenseParticipant(name: name, sharePaise: share));
          break;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    try {
      final expense = await widget.service.createExpense(
        amountPaise: amountPaise,
        category: _category,
        splitMethod: _splitMethod,
        participants: participants,
      );
      setState(() {
        _success =
            'Added ₹${_paiseToRupees(expense.amountPaise)} (${expense.category.label})';
        _amountController.clear();
        _participants.clear();
        _participants.add(_ParticipantRow());
        _participants.add(_ParticipantRow());
      });
      widget.onAdded?.call();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.draft != null) ..._draftBanner(colorScheme),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _fieldDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              highlighted: _highlighted.contains('amount'),
              hint: _highlighted.contains('amount') ? 'Not understood' : null,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ExpenseCategory>(
            initialValue: _category,
            decoration: _fieldDecoration(
              labelText: 'Category',
              highlighted: _highlighted.contains('category'),
              hint: _highlighted.contains('category') ? 'Not understood' : null,
            ),
            items: ExpenseCategory.values
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.label),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 16),
          SegmentedButton<SplitMethod>(
            segments: const [
              ButtonSegment(
                value: SplitMethod.equal,
                label: Text('Equal'),
                icon: Icon(Icons.filter_none),
              ),
              ButtonSegment(
                value: SplitMethod.ratio,
                label: Text('Ratio'),
                icon: Icon(Icons.percent),
              ),
              ButtonSegment(
                value: SplitMethod.adhoc,
                label: Text('Exact'),
                icon: Icon(Icons.edit),
              ),
            ],
            selected: {_splitMethod},
            onSelectionChanged: (s) => setState(() => _splitMethod = s.first),
          ),
          const SizedBox(height: 16),
          Text('Participants', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < _participants.length; i++)
            _participantField(i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _participants.add(_ParticipantRow())),
              icon: const Icon(Icons.add),
              label: const Text('Add Participant'),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          if (_success != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_success!, style: TextStyle(color: colorScheme.primary)),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_busy ? 'Adding…' : 'Add Expense'),
          ),
        ],
      ),
    );
  }

  /// Highlighted border (and hint) for a field the voice capture couldn't read.
  InputDecoration _fieldDecoration({
    required String labelText,
    String? prefixText,
    required bool highlighted,
    String? hint,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixText: prefixText,
      hintText: hint,
      errorText: highlighted ? 'Could not detect — please enter it' : null,
      border: const OutlineInputBorder(),
    );
  }

  /// A banner shown when the form was prefilled from a voice capture.
  List<Widget> _draftBanner(ColorScheme colorScheme) {
    final draft = widget.draft!;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice capture',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '“${draft.transcript}”',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Review and confirm the fields below.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _participantField(int index) {
    final row = _participants[index];
    final showValue =
        _splitMethod == SplitMethod.ratio || _splitMethod == SplitMethod.adhoc;
    final valueLabel = _splitMethod == SplitMethod.ratio ? 'Ratio' : 'Amount (₹)';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: showValue ? 3 : 4,
            child: TextField(
              controller: row.name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ),
          if (showValue) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: row.value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: valueLabel),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Remove',
            onPressed: _participants.length > 1
                ? () => setState(() => _participants.removeAt(index))
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}
