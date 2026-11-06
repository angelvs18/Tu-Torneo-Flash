import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/validators.dart';
import '../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// Opened by the router after a password-recovery deep link.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .updatePassword(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetPasswordTitle),
        automaticallyImplyLeading: false,
      ),
      body: AutofillGroup(
        child: AuthFormBody(
          formKey: _formKey,
          children: [
            PasswordField(
              controller: _password,
              label: l10n.newPasswordLabel,
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
              child: Text(l10n.resetPasswordSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
