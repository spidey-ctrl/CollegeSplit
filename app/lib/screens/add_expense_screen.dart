import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device_contacts.dart';
import '../services/expense_service.dart';

/// Form to add an Expense — amount, Category, Split Method and Participants.
///
/// Used both for manual entry (ticket 02) and as the confirm/edit screen after a
/// voice capture (ticket 03), where [draft] prefills the fields the app
/// understood and [draft.missingFields] marks the ones it couldn't extract.
/// Also used to edit a past Expense (ticket 08) by passing [existingExpense].
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({
    super.key,
    required this.service,
    this.onAdded,
    this.draft,
    this.existingExpense,
    this.deviceContacts,
  });

  final ExpenseService service;

  /// Called after an Expense is successfully created (e.g. to refresh a Ledger).
  final VoidCallback? onAdded;

  /// A voice-capture draft to prefill the form with (optional).
  final VoiceDraft? draft;

  /// A saved Expense to edit (optional, ticket 08). Mutually exclusive with
  /// [draft]; when set the form prefills and submits a PATCH instead of a POST.
  final Expense? existingExpense;

  /// Injectable for tests; defaults to the real device contact list.
  final DeviceContacts? deviceContacts;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _ParticipantRow {
  _ParticipantRow();

  final TextEditingController name = TextEditingController();
  // Ratio weight, or Adhoc rupees amount, depending on the split method.
  final TextEditingController value = TextEditingController();
  // Optional phone number used to resolve this Participant to a Contact.
  final TextEditingController phone = TextEditingController();
  // Whether this row represents the owning User (external-Payer Expenses).
  bool isUser = false;
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.foodDrink;
  SplitMethod _splitMethod = SplitMethod.equal;
  final List<_ParticipantRow> _participants = [];
  bool _busy = false;
  String? _error;
  String? _success;
  // Human-readable summary of how each non-ephemeral Participant resolved to a
  // Contact after the last submit (e.g. auto-linked or needs disambiguation).
  List<String> _resolved = const [];
  // Field names the voice capture couldn't confidently extract. These stay
  // blank and get a highlighted border until the User fills them in.
  final Set<String> _highlighted = {};

  late final DeviceContacts _deviceContacts =
      widget.deviceContacts ?? FlutterDeviceContacts();
  bool _contactsPermissionGranted = false;
  // Debounce (per participant row) so typing a name triggers at most one
  // device-contacts lookup after the User pauses.
  final Map<_ParticipantRow, Timer> _autoSuggestTimers = {};

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    final existing = widget.existingExpense;
    if (existing != null) {
      _splitMethod = existing.splitMethod;
      _amountController.text = _paiseToRupees(existing.amountPaise);
      _category = existing.category;
      for (final p in existing.participants) {
        final row = _ParticipantRow();
        row.name.text = p.name;
        row.isUser = p.isUser;
        // The ratio weight isn't stored on the shard, so a Ratio split needs
        // the User to re-enter weights; an Adhoc share is recoverable exactly.
        if (_splitMethod == SplitMethod.adhoc) {
          row.value.text = _paiseToRupees(p.sharePaise);
        }
        _participants.add(row);
      }
      _participants.add(_ParticipantRow());
    } else if (draft != null) {
      _splitMethod = draft.splitMethod;
      if (draft.amountPaise != null) {
        _amountController.text = _paiseToRupees(draft.amountPaise!);
      }
      if (draft.category != null) {
        _category = draft.category!;
      }
      // One row per understood participant (name + ratio for a Ratio split)
      // plus a trailing empty one for adding more.
      for (final p in draft.participants) {
        final row = _ParticipantRow();
        row.name.text = p.name;
        row.isUser = p.isUser;
        if (p.ratio != null) {
          row.value.text = p.ratio.toString();
        }
        _participants.add(row);
      }
      _participants.add(_ParticipantRow());
      _highlighted.addAll(draft.missingFields);
    } else {
      _participants.add(_ParticipantRow());
      _participants.add(_ParticipantRow());
    }

    // Voice-captured names are known immediately, so look up a device-contacts
    // phone for each without waiting for typing (ticket 06).
    for (final row in _participants) {
      if (row.name.text.trim().isNotEmpty) unawaited(_autoSuggestPhone(row));
    }
  }

  @override
  void dispose() {
    for (final t in _autoSuggestTimers.values) {
      t.cancel();
    }
    _amountController.dispose();
    for (final p in _participants) {
      p.name.dispose();
      p.value.dispose();
      p.phone.dispose();
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
      final phone = row.phone.text.trim();

      switch (_splitMethod) {
        case SplitMethod.equal:
          participants.add(
            ExpenseParticipant(
              name: name,
              phoneNumber: phone.isEmpty ? null : phone,
              isUser: row.isUser,
            ),
          );
          break;
        case SplitMethod.ratio:
          final ratio = int.tryParse(row.value.text.trim());
          if (ratio == null || ratio <= 0) {
            setState(() => _error = 'Give each Participant a ratio weight > 0');
            return;
          }
          participants.add(
            ExpenseParticipant(
              name: name,
              ratio: ratio,
              phoneNumber: phone.isEmpty ? null : phone,
              isUser: row.isUser,
            ),
          );
          break;
        case SplitMethod.adhoc:
          final share = _rupeesToPaise(row.value.text);
          if (share == null || share <= 0) {
            setState(() =>
                _error = 'Give each Participant an exact amount > 0');
            return;
          }
          participants.add(
            ExpenseParticipant(
              name: name,
              sharePaise: share,
              phoneNumber: phone.isEmpty ? null : phone,
              isUser: row.isUser,
            ),
          );
          break;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    try {
      final existing = widget.existingExpense;
      if (existing != null) {
        final updated = await widget.service.updateExpense(
          id: existing.id,
          amountPaise: amountPaise,
          category: _category,
          splitMethod: _splitMethod,
          payerName: existing.payerName,
          isUserPayer: existing.isUserPayer,
          participants: participants,
        );
        widget.onAdded?.call();
        if (mounted) Navigator.of(context).pop(updated);
        return;
      }

      final expense = await widget.service.createExpense(
        amountPaise: amountPaise,
        category: _category,
        splitMethod: _splitMethod,
        participants: participants,
      );
      setState(() {
        _success =
            'Added ₹${_paiseToRupees(expense.amountPaise)} (${expense.category.label})';
        _resolved = expense.participants
            .where((p) => p.contactMatch != null)
            .map((p) {
              final m = p.contactMatch!;
              return m.isAutoLinked
                  ? '${p.name} → saved as contact ${m.contactName}'
                  : '${p.name} → matches several contacts, please pick one';
            })
            .toList();
        _amountController.clear();
        _participants.clear();
        _participants.add(_ParticipantRow());
        _participants.add(_ParticipantRow());
      });
      widget.onAdded?.call();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Debounces a device-contacts lookup for [row] so it runs once the User
  /// pauses, then auto-suggests a phone onto that Participant if their name
  /// matches an entry in the device contact list.
  void _scheduleAutoSuggest(_ParticipantRow row) {
    _autoSuggestTimers[row]?.cancel();
    final name = row.name.text.trim();
    if (name.isEmpty) {
      _autoSuggestTimers.remove(row);
      return;
    }
    _autoSuggestTimers[row] = Timer(const Duration(milliseconds: 250), () {
      _autoSuggestTimers.remove(row);
      unawaited(_autoSuggestPhone(row));
    });
  }

  /// Requests contact permission (lazily, once) then, if granted, fills [row]'s
  /// phone with the first device-contact number matching its name. Any failure —
  /// including a denied permission — is swallowed so manual entry is never
  /// blocked and a manually-entered number is never overwritten.
  Future<void> _autoSuggestPhone(_ParticipantRow row) async {
    if (!mounted) return;
    if (row.phone.text.trim().isNotEmpty) return;
    final name = row.name.text.trim();
    if (name.isEmpty) return;
    try {
      if (!_contactsPermissionGranted) {
        final granted = await _deviceContacts.requestPermission();
        if (!mounted) return;
        _contactsPermissionGranted = granted;
        if (!granted) return; // denial → manual entry stays available
      }
      final phone = await _deviceContacts.lookupPhone(name);
      if (!mounted) return;
      if (phone != null && row.phone.text.trim().isEmpty) {
        setState(() => row.phone.text = phone);
      }
    } catch (_) {
      // Permission or lookup failures never block adding an Expense.
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _success!,
                    style: TextStyle(color: colorScheme.primary),
                  ),
                  for (final line in _resolved)
                    Text(
                      line,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
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
            label: Text(
              _busy
                  ? (_isEditing ? 'Saving…' : 'Adding…')
                  : (_isEditing ? 'Save Changes' : 'Add Expense'),
            ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: showValue ? 3 : 4,
                child: TextField(
                  controller: row.name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (_) => _scheduleAutoSuggest(row),
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
          TextField(
            controller: row.phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              hintText: 'To link to a Contact',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
