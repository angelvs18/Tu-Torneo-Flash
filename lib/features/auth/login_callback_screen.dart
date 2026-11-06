import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';

/// Landing for the auth deep link while the session is being restored.
/// The router leaves it as soon as the session arrives.
class LoginCallbackScreen extends StatelessWidget {
  const LoginCallbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(AppLocalizations.of(context).goHome),
            ),
          ],
        ),
      ),
    );
  }
}
