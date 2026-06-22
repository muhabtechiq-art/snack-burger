import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snack_burger/services/banner_image_upload_service.dart';

void main() {
  group('BannerImageUploadService preview limits', () {
    test('preview max width is at most 1200px', () {
      expect(BannerImageUploadService.previewMaxWidth, lessThanOrEqualTo(1200));
      expect(BannerImageUploadService.previewMaxHeight, lessThanOrEqualTo(1200));
    });
  });

  group('BannerImagePreviewResult', () {
    test('marks fallback when compression is skipped', () {
      final result = BannerImagePreviewResult(
        previewBytes: Uint8List.fromList(const [1]),
        usedFallback: true,
      );
      expect(result.usedFallback, isTrue);
    });
  });

  group('BannerImageUploadService.publicUrlWithCacheBust', () {
    test('appends v query parameter', () {
      final busted = BannerImageUploadService.publicUrlWithCacheBust(
        'https://example.com/storage/banner.jpg',
      );

      final uri = Uri.parse(busted);
      expect(uri.queryParameters.containsKey('v'), isTrue);
      expect(uri.queryParameters['v'], isNotEmpty);
    });

    test('replaces existing v parameter', () {
      final busted = BannerImageUploadService.publicUrlWithCacheBust(
        'https://example.com/storage/banner.jpg?v=1',
      );

      final uri = Uri.parse(busted);
      expect(uri.queryParameters['v'], isNot('1'));
    });
  });
}
