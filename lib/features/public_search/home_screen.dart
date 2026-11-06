import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';

/// Spectator home (§8.1). Search, QR and favorites arrive in M6.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.homeTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextField(
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.homeSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
            onSubmitted: (value) {
              final code = value.trim().toUpperCase();
              if (code.isNotEmpty) context.go(AppRoutes.tournament(code));
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: null, // TODO(M6): QR scanner
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l10n.homeScanQr),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go(AppRoutes.myTournaments),
            child: Text(l10n.homeOrganizerCta),
          ),
        ],
      ),
    );
  }
}
