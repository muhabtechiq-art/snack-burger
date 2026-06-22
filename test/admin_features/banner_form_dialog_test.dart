import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snack_burger/admin_features/banners/banner_form_dialog.dart';
import 'package:snack_burger/models/promo_banner_model.dart';
import 'package:snack_burger/services/banner_image_upload_service.dart';

class MockBannerImageUploadService extends Mock implements BannerImageUploadService {}

PromoBannerModel _sampleBanner() {
  return PromoBannerModel(
    id: 'b1',
    restaurantId: 'snack_burger',
    imageUrl: 'https://example.com/banner.jpg',
    title: 'عرض',
    isActive: true,
    sortOrder: 0,
    createdAt: DateTime.utc(2024, 6, 1),
  );
}

/// أصغر PNG صالح (1×1) لاختبارات معاينة الصورة.
Uint8List _tinyPngBytes() {
  return Uint8List.fromList(const <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
}

Future<void> _openEditDialog(
  WidgetTester tester,
  MockBannerImageUploadService mockService,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              showBannerFormDialog(
                context: context,
                uploadService: mockService,
                banner: _sampleBanner(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseBannerSortOrder', () {
    test('parses valid non-negative integers', () {
      expect(parseBannerSortOrder('0'), 0);
      expect(parseBannerSortOrder('3'), 3);
      expect(parseBannerSortOrder('  12  '), 12);
    });

    test('returns 0 for invalid or negative values', () {
      expect(parseBannerSortOrder(''), 0);
      expect(parseBannerSortOrder('abc'), 0);
      expect(parseBannerSortOrder('-1'), 0);
    });
  });

  group('BannerFormDialogResult', () {
    test('edit without image change keeps null image fields', () {
      const result = BannerFormDialogResult(
        title: 'عرض',
        isActive: true,
        sortOrder: 2,
        imageChanged: false,
      );

      expect(result.newImageFile, isNull);
      expect(result.newImageBytes, isNull);
      expect(result.imageChanged, isFalse);
    });

    test('edit with image change marks imageChanged true', () {
      const result = BannerFormDialogResult(
        title: 'عرض',
        isActive: true,
        sortOrder: 2,
        imageChanged: true,
      );

      expect(result.imageChanged, isTrue);
    });
  });

  group('PromoBannerModel update payload', () {
    test('copyWith preserves imageUrl when only metadata changes', () {
      final banner = PromoBannerModel(
        id: 'b1',
        restaurantId: 'snack_burger',
        imageUrl: 'https://example.com/old.jpg',
        title: 'قديم',
        isActive: false,
        sortOrder: 1,
        createdAt: DateTime.utc(2024, 1, 1),
      );

      final updated = banner.copyWith(
        title: 'جديد',
        isActive: true,
        sortOrder: 5,
      );

      expect(updated.imageUrl, banner.imageUrl);
      expect(updated.title, 'جديد');
      expect(updated.isActive, isTrue);
      expect(updated.sortOrder, 5);
      expect(updated.toUpdateMap()['image_url'], banner.imageUrl);
    });
  });

  group('BannerFormDialog image picking', () {
    late MockBannerImageUploadService mockService;

    setUpAll(() {
      registerFallbackValue(
        XFile.fromData(
          Uint8List.fromList([0]),
          name: 'fallback.png',
          mimeType: 'image/png',
        ),
      );
    });

    setUp(() {
      mockService = MockBannerImageUploadService();
    });

    testWidgets('shows loading while picker is open and clears on cancel', (
      tester,
    ) async {
      final pickerCompleter = Completer<XFile?>();
      when(() => mockService.pickBannerImageFromGallery())
          .thenAnswer((_) => pickerCompleter.future);

      await _openEditDialog(tester, mockService);
      await tester.tap(find.text('تغيير الصورة'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      pickerCompleter.complete(null);
      await tester.pumpAndSettle();

      expect(find.text('تغيير الصورة'), findsOneWidget);
      verify(() => mockService.pickBannerImageFromGallery()).called(1);
      verifyNever(() => mockService.prepareBannerImagePreview(any()));
      verifyNever(() => mockService.readAndCompress(any()));
    });

    testWidgets('loads preview and clears loading after successful pick', (
      tester,
    ) async {
      final bytes = _tinyPngBytes();
      final file = XFile.fromData(bytes, name: 'new.png', mimeType: 'image/png');

      when(() => mockService.pickBannerImageFromGallery())
          .thenAnswer((_) async => file);
      when(() => mockService.prepareBannerImagePreview(any())).thenAnswer(
        (_) async => BannerImagePreviewResult(previewBytes: bytes),
      );

      await _openEditDialog(tester, mockService);
      await tester.tap(find.text('تغيير الصورة'));
      await tester.pumpAndSettle();

      expect(find.text('اختيار صورة'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
      verify(() => mockService.pickBannerImageFromGallery()).called(1);
      verify(() => mockService.prepareBannerImagePreview(any())).called(1);
      verifyNever(() => mockService.readAndCompress(any()));
    });
  });
}
