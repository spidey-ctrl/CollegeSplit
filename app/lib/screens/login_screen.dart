import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.onSignIn,
    required this.busy,
    this.error,
  });

  final Future<void> Function() onSignIn;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text('CollegeSplit', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Split expenses with friends. No payment processing.'),
              const SizedBox(height: 32),
              if (error != null) ...[
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: busy ? null : onSignIn,
                icon: const Icon(Icons.g_mobiledata),
                label: Text(busy ? 'Signing in…' : 'Continue with Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
