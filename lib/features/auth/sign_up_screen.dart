import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/utils/validators.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.from});

  final String? from;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _confirmationSent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .signUp(email: _email.text, password: _password.text);
    // With email confirmation off Supabase returns a session and the router moves on.
    if (result == SignUpResult.confirmationSent && mounted) {
      setState(() => _confirmationSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signUpTitle)),
      body: AutofillGroup(
        child: AuthFormBody(
          formKey: _formKey,
          children: [
            if (_confirmationSent) ...[
              InfoBanner(text: l10n.signUpCheckEmail),
              const SizedBox(height: 16),
            ],
            EmailField(controller: _email),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              label: l10n.passwordLabel,
              validator: Validators.password,
              isNew: true,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirm,
              label: l10n.confirmPasswordLabel,
              validator: (v) =>
                  Validators.passwordConfirmation(v, _password.text),
              isNew: true,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 24),
            const AuthErrorText(),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(l10n.signUpSubmit),
            ),
            const SocialSignInButtons(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  context.go(AppRoutes.withFrom(AppRoutes.login, widget.from)),
              child: Text(l10n.signUpHaveAccount),
            ),
          ],
        ),
      ),
    );
  }
}
