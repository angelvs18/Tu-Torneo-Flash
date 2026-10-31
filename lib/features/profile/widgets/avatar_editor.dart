import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/session.dart';
import '../profile_controller.dart';

/// Current avatar plus a "change photo" button.
class AvatarEditor extends ConsumerWidget {
  const AvatarEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(sessionProvider.select((s) => s.profile));
    final action = ref.watch(profileControllerProvider);
    final url = profile?.avatarUrl;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: scheme.primaryContainer,
          foregroundImage: url == null ? null : NetworkImage(url),
          // Offline or broken URL: keep the placeholder icon.
          onForegroundImageError: url == null ? null : (_, _) {},
          child: Icon(Icons.person, size: 48, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: action.isLoading
              ? null
              : () =>
                    ref.read(profileControllerProvider.notifier).changeAvatar(),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.profileChangePhoto),
        ),
        if (action.failedAction == ProfileAction.changeAvatar)
          Text(l10n.photoUploadError, style: TextStyle(color: scheme.error)),
      ],
    );
  }
}
