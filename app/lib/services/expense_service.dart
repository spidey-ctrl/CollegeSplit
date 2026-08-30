import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Fixed, system-defined classifications of an Expense (see CONTEXT.md).
enum ExpenseCategory {
  foodDrink('FoodDrink', 'Food & Drink'),
  transport('Transport', 'Transport'),
  groceries('Groceries', 'Groceries'),
  rentUtilities('RentUtilities', 'Rent & Utilities'),
  travel('Travel', 'Travel'),
  entertainment('Entertainment', 'Entertainment'),
  other('Other', 'Other');

  const ExpenseCategory(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ExpenseCategory fromApi(String value) => values.firstWhere(
        (c) => c.apiValue == value,
        orElse: () => ExpenseCategory.other,
      );
}

/// The rule used to divide an Expense among its Participants (see CONTEXT.md).
enum SplitMethod {
  equal('Equal'),
  ratio('Ratio'),
  adhoc('Adhoc');

  const SplitMethod(this.apiValue);
  final String apiValue;

  static SplitMethod fromApi(String value) => values.firstWhere(
        (m) => m.apiValue == value,
        orElse: () => SplitMethod.equal,
      );
}

/// What the backend resolved a Participant to against the User's Contacts.
enum MatchKind { autoLinked, ambiguous }

class ParticipantMatch {
  const ParticipantMatch({
    required this.kind,
    this.contactId,
    this.contactName,
  });

  final MatchKind kind;

  /// Non-null when [kind] is [MatchKind.autoLinked].
  final String? contactId;

  /// Non-null when [kind] is [MatchKind.autoLinked].
  final String? contactName;

  bool get isAutoLinked => kind == MatchKind.autoLinked;

  factory ParticipantMatch.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    return ParticipantMatch(
      kind: kind == 'ambiguous' ? MatchKind.ambiguous : MatchKind.autoLinked,
      contactId: json['contactId'] as String?,
      contactName: json['contactName'] as String?,
    );
  }
}

class ExpenseParticipant {
  const ExpenseParticipant({
    required this.name,
    this.sharePaise = 0,
    this.isUser = false,
    this.ratio,
    this.phoneNumber,
    this.contactMatch,
  });

  final String name;
  final int sharePaise;
  final bool isUser;

  /// Only meaningful for a Ratio split (integer weight > 0).
  final int? ratio;

  /// Optional phone number used to resolve this Participant to a Contact.
  final String? phoneNumber;

  /// How the backend resolved this Participant on creation (null = ephemeral).
  final ParticipantMatch? contactMatch;
}

class Expense {
  const Expense({
    required this.id,
    required this.amountPaise,
    required this.category,
    required this.payerName,
    required this.isUserPayer,
    required this.splitMethod,
    this.settled = false,
    required this.createdAt,
    required this.participants,
  });

  final String id;
  final int amountPaise;
  final ExpenseCategory category;
  final String payerName;
  final bool isUserPayer;
  final SplitMethod splitMethod;

  /// Whether the running Balance this Expense contributed to has been settled
  /// (ticket 07). Editing or deleting a settled Expense reopens that Balance.
  final bool settled;
  final DateTime createdAt;
  final List<ExpenseParticipant> participants;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amountPaise: json['amountPaise'] as int,
        category: ExpenseCategory.fromApi(json['category'] as String),
        payerName: json['payerName'] as String,
        isUserPayer: json['isUserPayer'] as bool,
        splitMethod: SplitMethod.fromApi(json['splitMethod'] as String),
        settled: json['settled'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        participants: (json['participants'] as List<dynamic>)
            .map(
              (p) => ExpenseParticipant(
                name: p['name'] as String,
                sharePaise: p['sharePaise'] as int,
                isUser: p['isUser'] as bool,
                contactMatch: p['contactMatch'] == null
                    ? null
                    : ParticipantMatch.fromJson(
                        p['contactMatch'] as Map<String, dynamic>,
                      ),
              ),
            )
            .toList(),
      );
}

class LedgerEntry {
  const LedgerEntry({
    required this.counterparty,
    required this.balancePaise,
    this.contactId,
  });

  final String counterparty;

  /// Positive = this counterparty owes the User. Negative = the User owes them.
  final int balancePaise;

  /// The id of the User's Contact for this counterparty, when one exists.
  /// Non-null means the counterparty can be settled (ticket 07).
  final String? contactId;
}

class Ledger {
  const Ledger({
    required this.entries,
    required this.totalOwedToUserPaise,
    required this.totalUserOwesPaise,
  });

  final List<LedgerEntry> entries;
  final int totalOwedToUserPaise;
  final int totalUserOwesPaise;

  factory Ledger.fromJson(Map<String, dynamic> json) => Ledger(
        entries: (json['entries'] as List<dynamic>)
            .map(
              (e) => LedgerEntry(
                counterparty: e['counterparty'] as String,
                balancePaise: e['balancePaise'] as int,
                contactId: e['contactId'] as String?,
              ),
            )
            .toList(),
        totalOwedToUserPaise: json['totalOwedToUserPaise'] as int,
        totalUserOwesPaise: json['totalUserOwesPaise'] as int,
      );
}

/// A Contact is a person the User splits with repeatedly, auto-accumulated
/// from naming a Participant on 2+ Expenses (see CONTEXT.md).
class Contact {
  const Contact({required this.id, required this.name, this.phoneNumber});

  final String id;
  final String name;
  final String? phoneNumber;

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        phoneNumber: json['phoneNumber'] as String?,
      );
}

class VoiceDraftParticipant {
  const VoiceDraftParticipant({required this.name, this.ratio, this.isUser = false});

  final String name;

  /// Ratio weight for a Ratio split (Equal drafts omit it).
  final int? ratio;

  /// True when this participant represents the signed-in User.
  final bool isUser;

  factory VoiceDraftParticipant.fromJson(Map<String, dynamic> json) =>
      VoiceDraftParticipant(
        name: json['name'] as String,
        ratio: json['ratio'] as int?,
        isUser: json['isUser'] as bool? ?? false,
      );
}

/// A voice-capture draft returned by `POST /voice/capture` that prefills the
/// add-expense form. Nothing is persisted here; the User confirms or edits it.
///
/// A `null` field whose name appears in [missingFields] could not be extracted
/// confidently, so it should be left blank and highlighted on the form.
class VoiceDraft {
  const VoiceDraft({
    required this.transcript,
    required this.amountPaise,
    required this.category,
    required this.payerName,
    required this.isUserPayer,
    required this.splitMethod,
    required this.participants,
    required this.missingFields,
  });

  final String transcript;
  final int? amountPaise;
  final ExpenseCategory? category;
  final String? payerName;
  final bool isUserPayer;
  final SplitMethod splitMethod;
  final List<VoiceDraftParticipant> participants;
  final List<String> missingFields;

  bool get amountMissing => missingFields.contains('amount');
  bool get categoryMissing => missingFields.contains('category');

  factory VoiceDraft.fromJson(Map<String, dynamic> json) => VoiceDraft(
        transcript: json['transcript'] as String,
        amountPaise: json['amountPaise'] as int?,
        category: json['category'] == null
            ? null
            : ExpenseCategory.fromApi(json['category'] as String),
        payerName: json['payerName'] as String?,
        isUserPayer: json['isUserPayer'] as bool,
        splitMethod: SplitMethod.fromApi(json['splitMethod'] as String),
        participants: (json['participants'] as List<dynamic>)
            .map((p) => VoiceDraftParticipant.fromJson(p as Map<String, dynamic>))
            .toList(),
        missingFields: (json['missingFields'] as List<dynamic>)
            .map((f) => f as String)
            .toList(),
      );
}

/// What the backend hands back for a Share (ticket 10). Carries a read-only
/// text summary plus, when a phone is on file, a deep-link pre-target that
/// directs the native share sheet at that number.
enum ShareTargetKind { phone, none }

class ShareTarget {
  const ShareTarget({required this.kind, this.phoneNumber, this.deepLinkUrl});

  final ShareTargetKind kind;

  /// Non-null when [kind] is [ShareTargetKind.phone].
  final String? phoneNumber;

  /// Non-null when [kind] is [ShareTargetKind.phone] — e.g. a WhatsApp URL.
  final String? deepLinkUrl;

  static ShareTarget none() =>
      const ShareTarget(kind: ShareTargetKind.none);

  factory ShareTarget.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    if (kind == 'phone') {
      return ShareTarget(
        kind: ShareTargetKind.phone,
        phoneNumber: json['phoneNumber'] as String,
        deepLinkUrl: json['deepLinkUrl'] as String,
      );
    }
    return ShareTarget.none();
  }
}

class SharePayload {
  const SharePayload({required this.text, required this.target});

  /// Read-only summary of the shared Expense/Balance. Sharing is informational
  /// only — it never grants edit access or merges Ledgers.
  final String text;
  final ShareTarget target;

  factory SharePayload.fromJson(Map<String, dynamic> json) => SharePayload(
        text: json['text'] as String,
        target: ShareTarget.fromJson(json['target'] as Map<String, dynamic>),
      );
}

/// Calls the backend to create/read/edit/delete Expenses and read the User's
/// private Ledger.
class ExpenseService {
  ExpenseService({String? apiBaseUrl}) : _apiBaseUrl = apiBaseUrl ?? AuthService.apiBaseUrl;

  final String _apiBaseUrl;

  Future<String> _idToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');
    final token = await user.getIdToken();
    if (token == null) throw Exception('Failed to obtain Firebase ID token');
    return token;
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// Creates an Expense with the given split method.
  ///
  /// [participants] for Equal can be names only; for Ratio they carry a
  /// positive integer `ratio`; for Adhoc they carry an exact `sharePaise`.
  Future<Expense> createExpense({
    required int amountPaise,
    required ExpenseCategory category,
    required SplitMethod splitMethod,
    String? payerName,
    bool isUserPayer = true,
    List<ExpenseParticipant> participants = const [],
  }) async {
    final token = await _idToken();
    final res = await http.post(
      Uri.parse('$_apiBaseUrl/expenses'),
      headers: _headers(token),
      body: jsonEncode(
        _expenseBody(
          amountPaise: amountPaise,
          category: category,
          splitMethod: splitMethod,
          payerName: payerName,
          isUserPayer: isUserPayer,
          participants: participants,
        ),
      ),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('POST /expenses failed (${res.statusCode}): ${res.body}');
    }
    return Expense.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Fetches every Expense in the signed-in User's history, newest first
  /// (ticket 08). Settled Expenses are included so the history can show their
  /// settled state and still offer edit/delete.
  Future<List<Expense>> listExpenses() async {
    final token = await _idToken();
    final res = await http.get(
      Uri.parse('$_apiBaseUrl/expenses'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) {
      throw Exception('GET /expenses failed (${res.statusCode}): ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Edits a saved Expense (ticket 08). Editing a settled Expense reopens the
  /// Balance it belonged to.
  Future<Expense> updateExpense({
    required String id,
    required int amountPaise,
    required ExpenseCategory category,
    required SplitMethod splitMethod,
    String? payerName,
    bool isUserPayer = true,
    List<ExpenseParticipant> participants = const [],
  }) async {
    final token = await _idToken();
    final res = await http.patch(
      Uri.parse('$_apiBaseUrl/expenses/$id'),
      headers: _headers(token),
      body: jsonEncode(
        _expenseBody(
          amountPaise: amountPaise,
          category: category,
          splitMethod: splitMethod,
          payerName: payerName,
          isUserPayer: isUserPayer,
          participants: participants,
        ),
      ),
    );
    if (res.statusCode != 200) {
      throw Exception(
        'PATCH /expenses/$id failed (${res.statusCode}): ${res.body}',
      );
    }
    return Expense.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Deletes a saved Expense (ticket 08). Deleting a settled Expense reopens
  /// the Balance it belonged to.
  Future<void> deleteExpense(String id) async {
    final token = await _idToken();
    final res = await http.delete(
      Uri.parse('$_apiBaseUrl/expenses/$id'),
      headers: _headers(token),
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(
        'DELETE /expenses/$id failed (${res.statusCode}): ${res.body}',
      );
    }
  }

  /// Builds the request body shared by create and update.
  Map<String, dynamic> _expenseBody({
    required int amountPaise,
    required ExpenseCategory category,
    required SplitMethod splitMethod,
    String? payerName,
    bool isUserPayer = true,
    required List<ExpenseParticipant> participants,
  }) {
    return {
      'amountPaise': amountPaise,
      'category': category.apiValue,
      'splitMethod': splitMethod.apiValue,
      'payerName': ?payerName,
      'isUserPayer': isUserPayer,
      'participants': participants
          .map(
            (p) => {
              'name': p.name,
              if (p.phoneNumber != null && p.phoneNumber!.isNotEmpty)
                'phoneNumber': p.phoneNumber,
              if (p.ratio != null) 'ratio': p.ratio,
              if (splitMethod == SplitMethod.adhoc) 'sharePaise': p.sharePaise,
              'isUser': p.isUser,
            },
          )
          .toList(),
    };
  }

  /// Fetches the signed-in User's aggregate per-counterparty Balance.
  Future<Ledger> fetchLedger() async {
    final token = await _idToken();
    final res = await http.get(
      Uri.parse('$_apiBaseUrl/ledger'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) {
      throw Exception('GET /ledger failed (${res.statusCode})');
    }
    return Ledger.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Settles the User's whole running Balance with the Contact of [contactId],
  /// then returns the freshly-derived Ledger (that counterparty is now zero).
  Future<Ledger> settleCounterparty(String contactId) async {
    final token = await _idToken();
    final res = await http.post(
      Uri.parse('$_apiBaseUrl/ledger/$contactId/settle'),
      headers: _headers(token),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'POST /ledger/$contactId/settle failed (${res.statusCode}): ${res.body}',
      );
    }
    return Ledger.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Produces the native-fallback Share payload for one Expense (ticket 10).
  /// The payload carries a read-only text summary and, when the Participant has
  /// a phone on file, a pre-targeting deep link for the native share sheet.
  Future<SharePayload> shareExpense(String expenseId) async {
    final token = await _idToken();
    final res = await http.post(
      Uri.parse('$_apiBaseUrl/share/expense'),
      headers: _headers(token),
      body: jsonEncode({'expenseId': expenseId}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'POST /share/expense failed (${res.statusCode}): ${res.body}',
      );
    }
    return SharePayload.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Produces the native-fallback Share payload for the User's aggregate Balance
  /// with a single counterparty (ticket 10).
  Future<SharePayload> shareBalance(String counterparty) async {
    final token = await _idToken();
    final res = await http.post(
      Uri.parse('$_apiBaseUrl/share/balance'),
      headers: _headers(token),
      body: jsonEncode({'counterparty': counterparty}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        'POST /share/balance failed (${res.statusCode}): ${res.body}',
      );
    }
    return SharePayload.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Fetches the signed-in User's accumulated Contacts.
  Future<List<Contact>> fetchContacts() async {
    final token = await _idToken();
    final res = await http.get(
      Uri.parse('$_apiBaseUrl/contacts'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) {
      throw Exception('GET /contacts failed (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((c) => Contact.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Sends recorded audio (WAV) to the voice pipeline and returns a prefilled
  /// draft for the edit screen. Nothing is persisted server-side.
  Future<VoiceDraft> captureVoice({
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    final token = await _idToken();
    final res = await http.post(
      Uri.parse('$_apiBaseUrl/voice/capture'),
      headers: _headers(token),
      body: jsonEncode({
        'audioBase64': base64Encode(audioBytes),
        'mimeType': mimeType,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('POST /voice/capture failed (${res.statusCode}): ${res.body}');
    }
    return VoiceDraft.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
