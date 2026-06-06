import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/product_id_generator.dart';
import '../../models/product_model.dart';
import '../../services/image_pick_upload_service.dart';
import '../../services/image_upload_exception.dart';
import '../data/admin_repositories.dart';
import 'product_form_save_exception.dart';
import 'product_form_validators.dart';

/// حالة ومنطق نموذج إضافة/تعديل منتج — منفصل عن طبقة العرض.
class ProductFormController extends ChangeNotifier {
  ProductFormController({
    this.productId,
    AdminProductRepository? productRepository,
    ImagePickUploadService? imageService,
  })  : _productRepository = productRepository ?? AdminProductRepository(),
        _imageService = imageService ?? ImagePickUploadService();

  final String? productId;
  final AdminProductRepository _productRepository;
  final ImagePickUploadService _imageService;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final List<ProductAddonDraft> _addonDrafts = [];
  final List<ProductVariantDraft> _variantDrafts = [];
  bool _useMultipleSizes = false;

  XFile? _pickedImageFile;
  Uint8List? _webImage;
  String? _existingImageUrl;
  String? _errorMessage;
  bool _pickingImage = false;
  bool _uploadingImage = false;
  bool _saving = false;
  bool _loadingCategories = false;
  List<String> _categoryOptions = const [];
  bool _disposed = false;

  /// معرّف مؤقت للمنتج الجديد — يُولَّد مرة واحدة لمنع إدراجات متكررة.
  String? _draftProductId;

  bool get isEditing =>
      productId != null && productId!.trim().isNotEmpty;

  bool get saving => _saving;

  bool get uploadingImage => _uploadingImage;

  bool get isBusy => _saving || _uploadingImage || _pickingImage;

  bool get pickingImage => _pickingImage;

  bool get loadingCategories => _loadingCategories;

  List<String> get categoryOptions => List<String>.unmodifiable(_categoryOptions);

  String? get errorMessage => _errorMessage;

  XFile? get pickedImageFile => _pickedImageFile;

  Uint8List? get webImage => _webImage;

  String? get existingImageUrl => _existingImageUrl;

  List<ProductAddonDraft> get addonDrafts =>
      List<ProductAddonDraft>.unmodifiable(_addonDrafts);

  bool get useMultipleSizes => _useMultipleSizes;

  List<ProductVariantDraft> get variantDrafts =>
      List<ProductVariantDraft>.unmodifiable(_variantDrafts);

  void setUseMultipleSizes(bool value) {
    if (_useMultipleSizes == value) return;
    _useMultipleSizes = value;
    if (value) {
      if (_variantDrafts.isEmpty) {
        _variantDrafts.add(ProductVariantDraft());
      }
    } else {
      for (final draft in _variantDrafts) {
        draft.dispose();
      }
      _variantDrafts.clear();
    }
    notifyListeners();
  }

  void addVariantDraft() {
    _variantDrafts.add(ProductVariantDraft());
    notifyListeners();
  }

  void removeVariantDraftAt(int index) {
    if (index < 0 || index >= _variantDrafts.length) return;
    final removed = _variantDrafts.removeAt(index);
    removed.dispose();
    notifyListeners();
  }

  /// تحقق من إعدادات السعر قبل الحفظ (خارج FormState).
  String? validatePricingConfiguration() {
    if (_useMultipleSizes) {
      try {
        final variants = _buildVariants();
        if (variants.isEmpty) {
          return 'أضف حجماً واحداً على الأقل مع اسم وسعر';
        }
      } on FormatException catch (e) {
        return _mapVariantBuildError(e.message);
      }
      return null;
    }
    return ProductFormValidators.validatePositivePrice(priceController.text);
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// يحمّل قائمة التصنيفات من منتجات المطعم الحالية.
  Future<void> loadCategoryOptions({
    required String restaurantId,
    required String slug,
  }) async {
    if (_loadingCategories) return;

    _loadingCategories = true;
    if (!_disposed) notifyListeners();

    try {
      final categories = await _productRepository.fetchDistinctCategories(
        restaurantId: restaurantId,
        slug: slug,
      );
      if (_disposed) return;

      _categoryOptions = _mergeCategoryOptions(
        categories,
        categoryController.text.trim(),
      );
    } catch (e, st) {
      debugPrint('ProductFormController.loadCategoryOptions: $e\n$st');
      if (_disposed) return;
      _categoryOptions = _mergeCategoryOptions(
        const [],
        categoryController.text.trim(),
      );
    } finally {
      _loadingCategories = false;
      if (!_disposed) notifyListeners();
    }
  }

  List<String> _mergeCategoryOptions(
    List<String> fetched,
    String current,
  ) {
    final merged = <String>{...fetched};
    if (current.isNotEmpty) {
      merged.add(current);
    }
    final sorted = merged.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// يحمّل بيانات المنتج في حقول النموذج عند التعديل.
  Future<void> loadProductForEdit({
    required String restaurantId,
    required String slug,
  }) async {
    if (!isEditing) return;

    try {
      final product = await _productRepository.fetchProductById(
        restaurantId: restaurantId,
        slug: slug,
        productId: productId!,
      );
      if (_disposed || product == null) return;

      nameController.text = product.name;
      descriptionController.text = product.description ?? '';
      priceController.text = product.price.toStringAsFixed(0);
      categoryController.text = product.category;
      _categoryOptions = _mergeCategoryOptions(_categoryOptions, product.category);
      _existingImageUrl = product.imageUrl;
      _replaceAddonsFromProduct(product.addons);
      if (product.hasVariants) {
        _useMultipleSizes = true;
        _replaceVariantsFromProduct(product.variants);
        priceController.clear();
      } else {
        _useMultipleSizes = false;
        _clearVariantDrafts();
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('ProductFormController.loadProductForEdit: $e\n$st');
      if (_disposed) return;
      _setError('تعذّr تحميل بيانات المنتج');
    }
  }

  /// يختار صورة من المعرض ويحدّث المعاينة.
  Future<void> pickFromGallery() async {
    _setPickingImage(true);
    try {
      final file = await _imageService.pickProductImageFromGallery();
      if (file == null || _disposed) return;

      final bytes = await _imageService.readFileBytes(file);
      if (_disposed) return;

      if (bytes == null) {
        _setError('تعذّر قراءة ملف الصورة. جرّب صورة أخرى');
        return;
      }

      _pickedImageFile = file;
      _webImage = bytes;
      notifyListeners();
    } finally {
      _setPickingImage(false);
    }
  }

  /// يزيل الصورة المختارة أو المعروضة حالياً.
  void clearPickedImage() {
    _pickedImageFile = null;
    _webImage = null;
    _existingImageUrl = null;
    notifyListeners();
  }

  /// يبني نموذج المنتج من قيم الحقول الحالية.
  ProductModel buildProductModel({required String restaurantId}) {
    final description = descriptionController.text.trim();
    final variants = _useMultipleSizes ? _buildVariants() : const <ProductVariant>[];
    final double price;

    if (_useMultipleSizes) {
      if (variants.isEmpty) {
        throw const FormatException('Variant required');
      }
      price = variants.map((v) => v.price).reduce(
            (a, b) => a < b ? a : b,
          );
    } else {
      final parsed = ProductFormValidators.parsePositivePrice(
        priceController.text,
      );
      if (parsed == null) {
        throw const FormatException('Invalid price');
      }
      price = parsed;
    }

    final addons = _buildAddons();

    return ProductModel(
      id: _effectiveProductId(),
      restaurantId: restaurantId,
      name: nameController.text.trim(),
      description: description.isEmpty ? null : description,
      price: price,
      category: categoryController.text.trim(),
      addons: addons,
      variants: variants,
      imageUrl: _existingImageUrl,
      createdAt: DateTime.now().toUtc(),
    );
  }

  void addAddonDraft() {
    _addonDrafts.add(ProductAddonDraft());
    notifyListeners();
  }

  void removeAddonDraftAt(int index) {
    if (index < 0 || index >= _addonDrafts.length) return;
    final removed = _addonDrafts.removeAt(index);
    removed.dispose();
    notifyListeners();
  }

  List<ProductAddon> _buildAddons() {
    final addons = <ProductAddon>[];
    for (final draft in _addonDrafts) {
      final name = draft.nameController.text.trim();
      final priceRaw = draft.priceController.text.trim();
      if (name.isEmpty && priceRaw.isEmpty) {
        continue;
      }
      if (name.isEmpty) {
        throw const FormatException('Addon name required');
      }
      final price = ProductFormValidators.parsePositivePrice(priceRaw);
      if (price == null) {
        throw const FormatException('Addon price invalid');
      }
      addons.add(ProductAddon(name: name, price: price));
    }
    return addons;
  }

  List<ProductVariant> _buildVariants() {
    final variants = <ProductVariant>[];
    for (final draft in _variantDrafts) {
      final name = draft.nameController.text.trim();
      final priceRaw = draft.priceController.text.trim();
      if (name.isEmpty && priceRaw.isEmpty) {
        continue;
      }
      if (name.isEmpty) {
        throw const FormatException('Variant name required');
      }
      final price = ProductFormValidators.parsePositivePrice(priceRaw);
      if (price == null) {
        throw const FormatException('Variant price invalid');
      }
      variants.add(ProductVariant(name: name, price: price));
    }
    return variants;
  }

  void _replaceVariantsFromProduct(List<ProductVariant> variants) {
    _clearVariantDrafts();
    _variantDrafts.addAll(
      variants.map(
        (variant) => ProductVariantDraft(
          name: variant.name,
          price: variant.price.toStringAsFixed(0),
        ),
      ),
    );
  }

  void _clearVariantDrafts() {
    for (final draft in _variantDrafts) {
      draft.dispose();
    }
    _variantDrafts.clear();
  }

  String _mapVariantBuildError(String message) {
    if (message.contains('Variant name')) {
      return 'اسم الحجم مطلوب';
    }
    if (message.contains('Variant price')) {
      return 'سعر الحجم غير صالح';
    }
    if (message.contains('Variant required')) {
      return 'أضف حجماً واحداً على الأقل';
    }
    return 'تحقق من أحجام المنتج';
  }

  void _replaceAddonsFromProduct(List<ProductAddon> addons) {
    for (final draft in _addonDrafts) {
      draft.dispose();
    }
    _addonDrafts
      ..clear()
      ..addAll(
        addons.map(
          (addon) => ProductAddonDraft(
            name: addon.name,
            price: addon.price.toStringAsFixed(0),
          ),
        ),
      );
  }

  String _effectiveProductId() {
    final existing = productId?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    return _draftProductId ?? '';
  }

  void _ensureDraftProductId() {
    if (isEditing) return;
    _draftProductId ??= ProductIdGenerator.newId();
  }

  /// يحفظ المنتج ويعيد معرّف السجل في Supabase.
  ///
  /// يفترض أن طبقة العرض تحققت من صحة النموذج قبل الاستدعاء.
  Future<String> saveProduct({
    required String restaurantId,
    required String slug,
  }) async {
    if (_saving || _uploadingImage) {
      const msg = 'جاري الحفظ بالفعل';
      _setError(msg);
      throw ProductFormSaveException(msg);
    }

    _ensureDraftProductId();
    clearError();
    _setSaving(true);

    try {
      final product = buildProductModel(restaurantId: restaurantId);
      String? imageUrl;

      if (_pickedImageFile != null && _webImage != null) {
        _setUploadingImage(true);
        try {
          imageUrl = await _productRepository.uploadProductImage(
            restaurantId: restaurantId,
            slug: slug,
            pickedImageFile: _pickedImageFile!,
            pickedImageBytes: _webImage!,
            productId: product.id.trim().isNotEmpty ? product.id : null,
          );
          _existingImageUrl = imageUrl;
          debugPrint('[ProductFormController] image publicUrl: $imageUrl');
        } finally {
          if (!_disposed) _setUploadingImage(false);
        }
      } else {
        imageUrl = _existingImageUrl;
      }

      return await _productRepository.saveProduct(
        restaurantId: restaurantId,
        slug: slug,
        product: product,
        imageUrl: imageUrl,
      );
    } on ImageUploadException catch (e, st) {
      debugPrint('ProductFormController.saveProduct upload: $e\n$st');
      final msg = e.message;
      _setError(msg);
      throw ProductFormSaveException(msg, cause: e);
    } on PostgrestException catch (e, st) {
      debugPrint(
        'ProductFormController.saveProduct Supabase: '
        'code=${e.code} message=${e.message}\n$st',
      );
      final msg = _mapSaveError(e);
      _setError(msg);
      throw ProductFormSaveException(msg, cause: e);
    } on StorageException catch (e, st) {
      debugPrint(
        'ProductFormController.saveProduct Storage: ${e.message} $st',
      );
      final msg = _mapSaveError(e);
      _setError(msg);
      throw ProductFormSaveException(msg, cause: e);
    } on Exception catch (e, st) {
      debugPrint('ProductFormController.saveProduct: $e\n$st');
      final msg = _mapSaveError(e);
      _setError(msg);
      throw ProductFormSaveException(msg, cause: e);
    } catch (e, st) {
      debugPrint('ProductFormController.saveProduct unexpected: $e\n$st');
      const msg = 'تعذّr حفظ المنتج. حاول مرة أخرى';
      _setError(msg);
      throw ProductFormSaveException(msg, cause: e);
    } finally {
      if (!_disposed) {
        _setSaving(false);
        _setUploadingImage(false);
      }
    }
  }

  String _mapSaveError(Object error) {
    if (error is ImageUploadException) {
      return error.message;
    }
    if (error is PostgrestException) {
      if (error.code == '42501' || error.message.contains('permission')) {
        if (error.message.contains('product_addons') ||
            error.message.contains('الإضافات')) {
          return 'لا توجد صلاحية لحفظ الإضافات — '
              'فعّل سياسات INSERT/DELETE على product_addons';
        }
        if (error.message.contains('product_variants') ||
            error.message.contains('الأحجام')) {
          return 'لا توجد صلاحية لحفظ الأحجام — '
              'فعّل سياسات INSERT/DELETE على product_variants';
        }
        return 'لا توجد صلاحية لحفظ المنتج';
      }
      if (error.code == 'PGRST204') {
        return 'عمود ناقص في جدول products — '
            'أضف عمود category (وأعمدة أخرى) في Supabase';
      }
      if (error.code == '23505' || error.message.contains('duplicate_product')) {
        return 'يوجد منتج بنفس الاسم والسعر مسبقاً';
      }
      if (error.code == '22003') {
        return 'معرّف المنتج كبير جداً لقاعدة البيانات — '
            'غيّر نوع عمود id إلى bigint أو text في Supabase';
      }
      if (error.code == '400' || error.code == '22P02') {
        final detail = error.message.trim();
        if (detail.isNotEmpty && detail.length < 120) {
          return 'تعذّr حفظ المنتج: $detail';
        }
        return 'تعذّr حفظ المنتج — تحقق من نوع الحقول في Supabase';
      }
      return 'تعذّr حفظ المنتج. حاول مرة أخرى';
    }
    if (error is StorageException) {
      debugPrint(
        'StorageException: status=${error.statusCode} '
        'message=${error.message}',
      );
      if (error.statusCode == '403' || error.statusCode == '401') {
        return 'لا توجد صلاحية لرفع الصورة — '
            'فعّل سياسات Storage لـ bucket product-images في Supabase';
      }
      if (error.statusCode == '404') {
        return 'تعذّر رفع الصورة: تأكد من إنشاء bucket باسم product-images في Supabase';
      }
      return 'تعذّr رفع الصورة. حاول مرة أخرى';
    }
    if (error is TimeoutException) {
      return 'انتهت مهلة الاتصال. حاول مرة أخرى';
    }
    if (error is FormatException) {
      final msg = error.message.toString();
      if (msg.contains('Addon name')) {
        return 'اسم الإضافة مطلوب';
      }
      if (msg.contains('Addon price')) {
        return 'سعر الإضافة غير صالح';
      }
      if (msg.contains('Variant name')) {
        return 'اسم الحجم مطلوب';
      }
      if (msg.contains('Variant price')) {
        return 'سعر الحجم غير صالح';
      }
      if (msg.contains('Variant required')) {
        return 'أضف حجماً واحداً على الأقل';
      }
      return 'السعر غير صالح';
    }
    if (error is StateError) {
      return 'جاري الحفظ بالفعل';
    }
    return 'تعذّr حفظ المنتج. حاول مرة أخرى';
  }

  void _setError(String message) {
    _errorMessage = message;
    if (!_disposed) notifyListeners();
  }

  void _setPickingImage(bool value) {
    if (_pickingImage == value) return;
    _pickingImage = value;
    if (!_disposed) notifyListeners();
  }

  void _setUploadingImage(bool value) {
    if (_uploadingImage == value) return;
    _uploadingImage = value;
    if (!_disposed) notifyListeners();
  }

  void _setSaving(bool value) {
    if (_saving == value) return;
    _saving = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    categoryController.dispose();
    for (final draft in _addonDrafts) {
      draft.dispose();
    }
    _clearVariantDrafts();
    super.dispose();
  }
}

class ProductVariantDraft {
  ProductVariantDraft({String name = '', String price = ''})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price);

  final TextEditingController nameController;
  final TextEditingController priceController;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}

class ProductAddonDraft {
  ProductAddonDraft({String name = '', String price = ''})
      : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price);

  final TextEditingController nameController;
  final TextEditingController priceController;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
  }
}
