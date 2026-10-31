import 'package:flutter_test/flutter_test.dart';
import 'package:tu_torneo_flash/features/profile/profile_controller.dart';

void main() {
  test('contentTypeFor only produces types the bucket accepts', () {
    expect(contentTypeFor('a.PNG'), 'image/png');
    expect(contentTypeFor('a.webp'), 'image/webp');
    expect(contentTypeFor('a.jpg'), 'image/jpeg');
    expect(contentTypeFor('a.heic'), 'image/jpeg');
    expect(contentTypeFor('a', 'image/png'), 'image/png');
  });
}
