import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// The signed-in user's profile as returned by the backend `GET /users/me`.
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
  });

  final String id;
  final String displayName;
  final String email;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
      );
}

/// Handles Google Sign-In (via Firebase Auth) and the backend `/users/me` call.
class AuthService {
  AuthService() : _apiBaseUrl = apiBaseUrl;

  /// Backend base URL. Overridable at build time:
  /// `flutter run --dart-define=API_BASE_URL=https://...`
  /// Defaults to the Android emulator's loopback to the host machine.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  final String _apiBaseUrl;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize(
        serverClientId: loginOAuthClientId,
      );
      _initialized = true;
    }
  }

  /// The web OAuth client id for Google Sign-In, from `google-services.json`.
  static const String loginOAuthClientId =
      '266111353980-497ahfka834hk01g9dqn4m8ivu291v6e.apps.googleusercontent.com';

  /// Signs in with Google, exchanges the token with Firebase Auth, then fetches
  /// the user's profile from the backend and returns it (persisting the User on
  /// first sign-in).
  Future<AppUser> signIn() async {
    await _ensureInitialized();

    final googleAccount = await _googleSignIn.authenticate();
    final idToken = googleAccount.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google sign-in did not return an ID token');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _firebaseAuth.signInWithCredential(credential);

    final firebaseUser = _firebaseAuth.currentUser!;
    final firebaseIdToken = await firebaseUser.getIdToken();
    if (firebaseIdToken == null) {
      throw Exception('Failed to obtain Firebase ID token');
    }

    return _fetchMe(firebaseIdToken);
  }

  Future<AppUser> _fetchMe(String idToken) async {
    final res = await http.get(
      Uri.parse('$_apiBaseUrl/users/me'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('GET /users/me failed with status ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return AppUser.fromJson(body);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
