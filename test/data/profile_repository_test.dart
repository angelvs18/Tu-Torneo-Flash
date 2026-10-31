import 'package:flutter_test/flutter_test.dart';
import 'package:tu_torneo_flash/data/dto/profile.dart';
import 'package:tu_torneo_flash/data/repositories/profile_repository.dart';

void main() {
  test('avatars live in the user folder with a fixed name', () {
    expect(avatarObjectPath('u1'), 'u1/avatar');
  });

  test('withCacheBuster sets v and keeps other params', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    expect(
      withCacheBuster(
        'https://x.supabase.co/storage/v1/object/public/avatars/u1/avatar',
        at,
      ),
      'https://x.supabase.co/storage/v1/object/public/avatars/u1/avatar?v=1700000000000',
    );
    expect(
      withCacheBuster('https://cdn.test/a?v=1&w=2', at),
      'https://cdn.test/a?v=1700000000000&w=2',
    );
  });

  test('Profile reads snake_case columns', () {
    final p = Profile.fromJson({
      'id': 'u1',
      'display_name': 'Ana',
      'avatar_url': null,
      'created_at': '2026-10-31T00:00:00Z',
      'updated_at': '2026-10-31T01:00:00Z',
    });
    expect(p.displayName, 'Ana');
    expect(p.updatedAt, DateTime.utc(2026, 10, 31, 1));
  });
}
