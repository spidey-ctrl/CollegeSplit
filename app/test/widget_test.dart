import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collegesplit/screens/login_screen.dart';

void main() {
  testWidgets('Login screen shows title and Google sign-in button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(onSignIn: _noopSignIn, busy: false),
      ),
    );

    expect(find.text('CollegeSplit'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}

Future<void> _noopSignIn() async {}
