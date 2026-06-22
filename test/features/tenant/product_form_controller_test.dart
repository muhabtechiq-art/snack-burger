import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snack_burger/admin_features/data/admin_repositories.dart';
import 'package:snack_burger/admin_features/products/product_form_controller.dart';
import 'package:snack_burger/admin_features/products/product_form_validators.dart';
import 'package:snack_burger/models/product_model.dart';
import 'package:snack_burger/services/image_pick_upload_service.dart';

class MockAdminProductRepository extends Mock implements AdminProductRepository {}

class MockImagePickUploadService extends Mock implements ImagePickUploadService {}

ProductModel _sampleProduct() {
  return ProductModel(
    id: 'prod-1',
    restaurantId: 'snack_burger',
    name: 'برجر كلاسيك',
    description: 'وصف تجريبي',
    price: 12000,
    category: 'برجر',
    imageUrl: 'https://example.com/burger.png',
    createdAt: DateTime.utc(2024, 6, 15, 10, 30),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdminProductRepository mockRepository;
  late MockImagePickUploadService mockImageService;

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
    mockRepository = MockAdminProductRepository();
    mockImageService = MockImagePickUploadService();
  });

  group('ProductFormController', () {
    ProductFormController? controller;

    tearDown(() {
      controller?.dispose();
      controller = null;
    });

    test('loadProductForEdit populates text controllers from repository', () async {
      final product = _sampleProduct();
      when(
        () => mockRepository.fetchProductById(
          restaurantId: any(named: 'restaurantId'),
          slug: any(named: 'slug'),
          productId: any(named: 'productId'),
        ),
      ).thenAnswer((_) => Future<ProductModel?>.value(product));

      controller = ProductFormController(
        productId: product.id,
        productRepository: mockRepository,
      );

      await controller!.loadProductForEdit(
        restaurantId: product.restaurantId,
        slug: 'snack_burger',
      );

      expect(controller!.nameController.text, product.name);
      expect(controller!.descriptionController.text, product.description);
      expect(controller!.priceController.text, product.price.toStringAsFixed(0));
      expect(controller!.categoryController.text, product.category);
      expect(controller!.existingImageUrl, product.imageUrl);
      expect(controller!.isEditing, isTrue);

      verify(
        () => mockRepository.fetchProductById(
          restaurantId: product.restaurantId,
          slug: 'snack_burger',
          productId: product.id,
        ),
      ).called(1);
    });

    test('loadProductForEdit does nothing when not in edit mode', () async {
      controller = ProductFormController(productRepository: mockRepository);

      await controller!.loadProductForEdit(
        restaurantId: 'snack_burger',
        slug: 'snack_burger',
      );

      expect(controller!.nameController.text, isEmpty);
      expect(controller!.isEditing, isFalse);
      verifyNever(
        () => mockRepository.fetchProductById(
          restaurantId: any(named: 'restaurantId'),
          slug: any(named: 'slug'),
          productId: any(named: 'productId'),
        ),
      );
    });

    test('clearPickedImage resets all image state to null', () async {
      final product = _sampleProduct();
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final file = XFile.fromData(bytes, name: 'photo.png', mimeType: 'image/png');

      when(
        () => mockRepository.fetchProductById(
          restaurantId: any(named: 'restaurantId'),
          slug: any(named: 'slug'),
          productId: any(named: 'productId'),
        ),
      ).thenAnswer((_) => Future<ProductModel?>.value(product));
      when(() => mockImageService.pickProductImageFromGallery())
          .thenAnswer((_) async => file);
      when(() => mockImageService.readFileBytes(file)).thenAnswer((_) async => bytes);

      controller = ProductFormController(
        productId: product.id,
        productRepository: mockRepository,
        imageService: mockImageService,
      );

      await controller!.loadProductForEdit(
        restaurantId: product.restaurantId,
        slug: 'snack_burger',
      );

      expect(controller!.existingImageUrl, product.imageUrl);

      await controller!.pickFromGallery();

      expect(controller!.pickedImageFile, isNotNull);
      expect(controller!.webImage, isNotNull);
      expect(controller!.existingImageUrl, isNull);

      controller!.clearPickedImage();

      expect(controller!.pickedImageFile, isNull);
      expect(controller!.webImage, isNull);
      expect(controller!.existingImageUrl, isNull);
    });

    test('pickFromGallery clears picking state when user cancels', () async {
      when(() => mockImageService.pickProductImageFromGallery())
          .thenAnswer((_) async => null);

      controller = ProductFormController(
        productRepository: mockRepository,
        imageService: mockImageService,
      );

      await controller!.pickFromGallery();

      expect(controller!.pickingImage, isFalse);
      expect(controller!.pickedImageFile, isNull);
      expect(controller!.webImage, isNull);
      expect(controller!.errorMessage, isNull);
      verify(() => mockImageService.pickProductImageFromGallery()).called(1);
      verifyNever(() => mockImageService.readFileBytes(any()));
    });

    test('pickFromGallery leaves picking false after successful pick', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final file = XFile.fromData(bytes, name: 'photo.png', mimeType: 'image/png');

      when(() => mockImageService.pickProductImageFromGallery())
          .thenAnswer((_) async => file);
      when(() => mockImageService.readFileBytes(any())).thenAnswer((_) async => bytes);

      controller = ProductFormController(
        productRepository: mockRepository,
        imageService: mockImageService,
      );

      await controller!.pickFromGallery();

      expect(controller!.pickingImage, isFalse);
      expect(controller!.pickedImageFile, file);
      expect(controller!.webImage, bytes);
      expect(controller!.errorMessage, isNull);
      verify(() => mockImageService.pickProductImageFromGallery()).called(1);
      verify(() => mockImageService.readFileBytes(any())).called(1);
    });
  });

  group('ProductFormValidators', () {
    test('validateRequiredName rejects empty and whitespace-only values', () {
      expect(ProductFormValidators.validateRequiredName(null), 'اسم الوجبة مطلوب');
      expect(ProductFormValidators.validateRequiredName(''), 'اسم الوجبة مطلوب');
      expect(ProductFormValidators.validateRequiredName('   '), 'اسم الوجبة مطلوب');
    });

    test('validateRequiredName accepts non-empty trimmed name', () {
      expect(ProductFormValidators.validateRequiredName('برجر'), isNull);
      expect(ProductFormValidators.validateRequiredName('  بيتزا  '), isNull);
    });

    test('validatePositivePrice rejects empty, invalid, zero, and negative values', () {
      expect(ProductFormValidators.validatePositivePrice(null), 'السعر مطلوب');
      expect(ProductFormValidators.validatePositivePrice(''), 'السعر مطلوب');
      expect(ProductFormValidators.validatePositivePrice('abc'), 'أدخل أرقاماً فقط');
      expect(ProductFormValidators.validatePositivePrice('0'), 'يجب أن يكون السعر أكبر من 0');
    });

    test('validatePositivePrice accepts positive integer values only', () {
      expect(ProductFormValidators.validatePositivePrice('1500'), isNull);
      expect(ProductFormValidators.validatePositivePrice('1,500'), isNull);
      expect(ProductFormValidators.validatePositivePrice('6000'), isNull);
    });

    test('parsePositivePrice returns null for invalid or non-positive values', () {
      expect(ProductFormValidators.parsePositivePrice(''), isNull);
      expect(ProductFormValidators.parsePositivePrice('0'), isNull);
      expect(ProductFormValidators.parsePositivePrice('abc'), isNull);
    });

    test('parsePositivePrice normalizes digits-only Iraqi prices', () {
      expect(ProductFormValidators.parsePositivePrice('2500'), 2500);
      expect(ProductFormValidators.parsePositivePrice('12.5'), 125);
      expect(ProductFormValidators.parsePositivePrice('6.000'), 6000);
    });
  });
}
