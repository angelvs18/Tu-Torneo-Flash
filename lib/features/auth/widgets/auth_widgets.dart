import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../auth_controller.dart';
import '../auth_messages.dart';

/// Scrollable, width-limited body shared by the auth screens.
class AuthFormBody extends StatelessWidget {
  const AuthFormBody({
    super.key,
    required this.formKey,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: l10n.emailLabel),
      validator: (v) => _msg(l10n, Validators.email(v)),
    );
  }
}

class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.isNew = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FieldError? Function(String?) validator;
  final bool isNew;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      obscureText: true,
      autofillHints: [
        isNew ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(labelText: label),
      validator: (v) => _msg(l10n, validator(v)),
    );
  }
}

String? _msg(AppLocalizations l10n, FieldError? e) =>
    e == null ? null : l10n.fieldError(e);

/// Shows the last [AuthController] error, if any.
class AuthErrorText extends ConsumerWidget {
  const AuthErrorText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(authControllerProvider).error;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        AppLocalizations.of(context).authError(error),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
      ),
    );
  }
}

/// Google (when configured) and Apple (iOS) buttons.
class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(authRepositoryProvider);
    if (!repo.isGoogleAvailable && !repo.isAppleAvailable) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authControllerProvider).isLoading;
    final controller = ref.read(authControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l10n.loginOr),
              ),
              const Expanded(child: Divider()),
            ],
          ),
        ),
        // TODO(design): official Google/Apple button artwork.
        if (repo.isGoogleAvailable)
          OutlinedButton.icon(
            onPressed: busy ? null : controller.signInWithGoogle,
            icon: const Icon(Icons.g_mobiledata, size: 32),
            label: Text(l10n.loginWithGoogle),
          ),
        if (repo.isGoogleAvailable && repo.isAppleAvailable)
          const SizedBox(height: 12),
        if (repo.isAppleAvailable)
          OutlinedButton.icon(
            onPressed: busy ? null : controller.signInWithApple,
            icon: const Icon(Icons.apple),
            label: Text(l10n.loginWithApple),
          ),
      ],
    );
  }
}
