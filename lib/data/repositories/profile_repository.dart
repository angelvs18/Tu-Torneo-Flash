import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dto/profile.dart';
import '../supabase_client.dart';

part 'profile_repository.g.dart';

const avatarsBucket = 'avatars';

/// One object per user, overwritten on every upload (no orphans when the
/// format changes). The storage policy only allows `{uid}/<file>`.
String avatarObjectPath(String userId) => '$userId/avatar';

/// The public URL never changes, so a version param busts image caches.
String withCacheBuster(String url, DateTime at) {
  final uri = Uri.parse(url);
  return uri
      .replace(
        queryParameters: {
          ...uri.queryParameters,
          'v': '${at.millisecondsSinceEpoch}',
        },
      )
      .toString();
}

/// Profile of the signed-in user. Every method requires a session.
abstract interface class ProfileRepository {
  Future<Profile?> fetchMine();
  Future<Profile> updateDisplayName(String displayName);

  /// Sets the name only if it is still null (e.g. the name Apple shares once).
  Future<void> fillDisplayNameIfMissing(String displayName);

  /// [contentType] must be image/jpeg, image/png or image/webp (bucket rule).
  Future<Profile> uploadAvatar(Uint8List bytes, {required String contentType});
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No session');
    return id;
  }

  SupabaseQueryBuilder get _table => _client.from('profiles');

  @override
  Future<Profile?> fetchMine() async {
    final row = await _table.select().eq('id', _uid).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  @override
  Future<Profile> updateDisplayName(String displayName) =>
      _update({'display_name': displayName.trim()});

  @override
  Future<void> fillDisplayNameIfMissing(String displayName) => _table
      .update({'display_name': displayName.trim()})
      .eq('id', _uid)
      .isFilter('display_name', null);

  @override
  Future<Profile> uploadAvatar(
    Uint8List bytes, {
    required String contentType,
  }) async {
    final path = avatarObjectPath(_uid);
    final bucket = _client.storage.from(avatarsBucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(upsert: true, contentType: contentType),
    );
    return _update({
      'avatar_url': withCacheBuster(bucket.getPublicUrl(path), _clock()),
    });
  }

  Future<Profile> _update(Map<String, Object?> values) async {
    final row = await _table.update(values).eq('id', _uid).select().single();
    return Profile.fromJson(row);
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    SupabaseProfileRepository(ref.watch(supabaseClientProvider));
