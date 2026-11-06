import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(authControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
      body: AuthFormBody(
        formKey: _formKey,
        children: [
          Text(l10n.forgotPasswordBody),
          const SizedBox(height: 16),
          if (_sent) ...[
            InfoBanner(text: l10n.forgotPasswordSent),
            const SizedBox(height: 16),
          ],
          EmailField(controller: _email),
          const SizedBox(height: 24),
          const AuthErrorText(),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: Text(l10n.forgotPasswordSubmit),
          ),
        ],
      ),
    );
  }
}
