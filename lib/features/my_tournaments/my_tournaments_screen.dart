import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';

/// Organizer home (§8.5). The tournament list lands in the next M1 step.
class MyTournamentsScreen extends StatelessWidget {
  const MyTournamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myTournamentsTitle),
        actions: [
          IconButton(
            tooltip: l10n.profileTooltip,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: Center(child: Text(l10n.comingSoon)),
    );
  }
}
