import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/validators.dart';
import '../../l10n/generated/app_localizations.dart';
import '../profile/profile_controller.dart';
import '../profile/widgets/avatar_editor.dart';
import 'auth_messages.dart';
import 'widgets/auth_widgets.dart';

/// Shown by the router while the signed-in user has no display name.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // On success Session gets the name and the router leaves this screen.
    await ref.read(profileControllerProvider.notifier).saveName(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.completeProfileTitle),
        automaticallyImplyLeading: false,
      ),
      body: AuthFormBody(
        formKey: _formKey,
        children: [
          Text(l10n.completeProfileBody),
          const SizedBox(height: 24),
          const AvatarEditor(),
          const SizedBox(height: 16),
          DisplayNameField(controller: _name, onSubmitted: _submit),
          const SizedBox(height: 24),
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
            onPressed: state.isLoading ? null : _submit,
            child: Text(l10n.completeProfileSubmit),
          ),
        ],
      ),
    );
  }
}

class DisplayNameField extends StatelessWidget {
  const DisplayNameField({
    super.key,
    required this.controller,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.name],
      maxLength: Validators.displayNameMaxLength,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(
        labelText: l10n.displayNameLabel,
        helperText: l10n.displayNameHint,
      ),
      validator: (v) {
        final e = Validators.displayName(v);
        return e == null ? null : l10n.fieldError(e);
      },
    );
  }
}
