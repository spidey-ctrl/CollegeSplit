import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_error.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CollegeSplitApp());
}

class CollegeSplitApp extends StatefulWidget {
  const CollegeSplitApp({super.key});

  @override
  State<CollegeSplitApp> createState() => _CollegeSplitAppState();
}

class _CollegeSplitAppState extends State<CollegeSplitApp> {
  final AuthService _auth = AuthService();
  AppUser? _user;
  bool _busy = false;
  String? _error;

  Future<void> _handleSignIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await _auth.signIn();
      setState(() => _user = user);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _handleSignOut() async {
    await _auth.signOut();
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CollegeSplit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: _user == null
          ? LoginScreen(
              onSignIn: _handleSignIn,
              busy: _busy,
              error: _error,
            )
          : HomeScreen(user: _user!, onSignOut: _handleSignOut),
    );
  }
}
