import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../auth/complete_profile_screen.dart';
import '../auth/session.dart';
import '../auth/widgets/auth_widgets.dart';
import 'profile_controller.dart';
import 'widgets/avatar_editor.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: ref.read(sessionProvider).profile?.displayName ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .saveName(_name.text);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
      );
    }
  }

  Future<void> _signOut() async {
    final router = GoRouter.of(context);
    if (await ref.read(authControllerProvider.notifier).signOut()) {
      router.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = ref.watch(sessionProvider.select((s) => s.user?.email));
    final state = ref.watch(profileControllerProvider);
    final signingOut = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: AuthFormBody(
        formKey: _formKey,
        children: [
          const AvatarEditor(),
          if (email != null) ...[
            const SizedBox(height: 8),
            Text(email, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          DisplayNameField(controller: _name, onSubmitted: _save),
          const SizedBox(height: 16),
          if (state.failedAction == ProfileAction.saveName)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.authErrorUnknown,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          FilledButton(
            onPressed: state.isLoading ? null : _save,
            child: Text(l10n.profileSave),
          ),
          const SizedBox(height: 32),
          const AuthErrorText(),
          OutlinedButton.icon(
            onPressed: signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: Text(l10n.profileSignOut),
          ),
        ],
      ),
    );
  }
}
