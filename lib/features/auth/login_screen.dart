import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/utils/validators.dart';
import '../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});

  /// Where to go after signing in (handled by the router redirect).
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: AutofillGroup(
        child: AuthFormBody(
          formKey: _formKey,
          children: [
            EmailField(controller: _email),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              label: l10n.passwordLabel,
              // Only presence: older accounts may predate the length rule.
              validator: (v) => (v ?? '').isEmpty ? FieldError.required : null,
              onSubmitted: _submit,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.forgotPassword),
                child: Text(l10n.loginForgotPassword),
              ),
            ),
            const SizedBox(height: 8),
            const AuthErrorText(),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(l10n.loginSubmit),
            ),
            const SocialSignInButtons(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  context.go(AppRoutes.withFrom(AppRoutes.signUp, widget.from)),
              child: Text(l10n.loginNoAccount),
            ),
          ],
        ),
      ),
    );
  }
}
