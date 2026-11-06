import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/profile_repository.dart';
import '../auth/session.dart';

part 'profile_controller.g.dart';

class PickedImage {
  const PickedImage(this.bytes, this.contentType);

  final Uint8List bytes;
  final String contentType;
}

typedef AvatarPicker = Future<PickedImage?> Function();

/// Gallery picker, downscaled on device to 512 px (§9). Overridden in tests.
@riverpod
AvatarPicker avatarPicker(Ref ref) => () async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (file == null) return null;
  return PickedImage(
    await file.readAsBytes(),
    contentTypeFor(file.path, file.mimeType),
  );
};

/// The bucket accepts png, webp and jpeg; anything else is sent as jpeg.
String contentTypeFor(String path, [String? mimeType]) {
  if (mimeType != null && mimeType.startsWith('image/')) return mimeType;
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

enum ProfileAction { saveName, changeAvatar }

/// Edits the signed-in user's profile and keeps [Session] in sync.
@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<ProfileAction?> build() => null;

  Future<bool> saveName(String name) => _run(ProfileAction.saveName, () async {
    final profile = await ref
        .read(profileRepositoryProvider)
        .updateDisplayName(name);
    ref.read(sessionProvider.notifier).setProfile(profile);
  });

  Future<bool> changeAvatar() => _run(ProfileAction.changeAvatar, () async {
    final image = await ref.read(avatarPickerProvider)();
    if (image == null) return;
    final profile = await ref
        .read(profileRepositoryProvider)
        .uploadAvatar(image.bytes, contentType: image.contentType);
    ref.read(sessionProvider.notifier).setProfile(profile);
  });

  /// `state` holds the finished action (or the error) so the UI can react.
  Future<bool> _run(ProfileAction action, Future<void> Function() body) async {
    state = const AsyncLoading<ProfileAction?>();
    try {
      await body();
      if (ref.mounted) state = AsyncData(action);
      return true;
    } on Exception catch (e, st) {
      if (ref.mounted) {
        state = AsyncError<ProfileAction?>(_Failed(action, e), st);
      }
      return false;
    }
  }
}

class _Failed implements Exception {
  const _Failed(this.action, this.cause);

  final ProfileAction action;
  final Exception cause;
}

extension ProfileActionError on AsyncValue<ProfileAction?> {
  /// Which action failed, if the last one did.
  ProfileAction? get failedAction => switch (error) {
    final _Failed f => f.action,
    _ => null,
  };
}
