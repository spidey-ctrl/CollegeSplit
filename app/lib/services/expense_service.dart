import 'dart:async';
import 'dart:convert';

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

class ExpenseParticipant {
  const ExpenseParticipant({
    required this.name,
    this.sharePaise = 0,
    this.isUser = false,
    this.ratio,
  });

  final String name;
  final int sharePaise;
  final bool isUser;

  /// Only meaningful for a Ratio split (integer weight > 0).
  final int? ratio;
}

class Expense {
  const Expense({
    required this.id,
    required this.amountPaise,
    required this.category,
    required this.payerName,
    required this.isUserPayer,
    required this.splitMethod,
    required this.createdAt,
    required this.participants,
  });

  final String id;
  final int amountPaise;
  final ExpenseCategory category;
  final String payerName;
  final bool isUserPayer;
  final SplitMethod splitMethod;
  final DateTime createdAt;
  final List<ExpenseParticipant> participants;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        amountPaise: json['amountPaise'] as int,
        category: ExpenseCategory.fromApi(json['category'] as String),
        payerName: json['payerName'] as String,
        isUserPayer: json['isUserPayer'] as bool,
        splitMethod: SplitMethod.fromApi(json['splitMethod'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        participants: (json['participants'] as List<dynamic>)
            .map(
              (p) => ExpenseParticipant(
                name: p['name'] as String,
                sharePaise: p['sharePaise'] as int,
                isUser: p['isUser'] as bool,
              ),
            )
            .toList(),
      );
}

class LedgerEntry {
  const LedgerEntry({required this.counterparty, required this.balancePaise});

  final String counterparty;

  /// Positive = this counterparty owes the User. Negative = the User owes them.
  final int balancePaise;
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
              ),
            )
            .toList(),
        totalOwedToUserPaise: json['totalOwedToUserPaise'] as int,
        totalUserOwesPaise: json['totalUserOwesPaise'] as int,
      );
}

/// Calls the backend to create Expenses and read the User's private Ledger.
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
      body: jsonEncode({
        'amountPaise': amountPaise,
        'category': category.apiValue,
        'splitMethod': splitMethod.apiValue,
        'payerName': ?payerName,
        'isUserPayer': isUserPayer,
        'participants': participants
            .map(
              (p) => {
                'name': p.name,
                if (p.ratio != null) 'ratio': p.ratio,
                if (splitMethod == SplitMethod.adhoc) 'sharePaise': p.sharePaise,
                'isUser': p.isUser,
              },
            )
            .toList(),
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('POST /expenses failed (${res.statusCode}): ${res.body}');
    }
    return Expense.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
}
