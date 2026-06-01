import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../state/active_restaurant_notifier.dart';
import '../shell/admin_page_scaffold.dart';
import 'product_form_controller.dart';
import 'product_form_save_exception.dart';
import 'product_form_validators.dart';
import 'widgets/product_category_field.dart';
import 'widgets/product_image_picker_field.dart';

/// إضافة أو تعديل منتج — مع اختيار صورة من المعرض ومعاينة فورية.
class ProductFormPage extends StatelessWidget {
  const ProductFormPage({
    super.key,
    required this.slug,
  });

  final String slug;

  @override
  Widget build(BuildContext context) {
    return _ProductFormSlugResolver(
      slug: slug,
      child: Consumer<ProductFormController>(
        builder: (context, controller, _) {
          return AdminPageScaffold(
            slug: slug,
            title: controller.isEditing ? 'تعديل منتج' : 'إضافة منتج',
            body: const _ProductFormBody(),
          );
        },
      ),
    );
  }
}

class _ProductFormSlugResolver extends StatefulWidget {
  const _ProductFormSlugResolver({
    required this.slug,
    required this.child,
  });

  final String slug;
  final Widget child;

  @override
  State<_ProductFormSlugResolver> createState() =>
      _ProductFormSlugResolverState();
}

class _ProductFormSlugResolverState extends State<_ProductFormSlugResolver> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActiveRestaurantNotifier>().resolveSlug(widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ProductFormBody extends StatefulWidget {
  const _ProductFormBody();

  @override
  State<_ProductFormBody> createState() => _ProductFormBodyState();
}

class _ProductFormBodyState extends State<_ProductFormBody> {
  final _formKey = GlobalKey<FormState>();
  bool _loadedForEdit = false;
  bool _categoriesLoaded = false;
  bool _saveLocked = false;

  void _maybeLoadCategories(
    ActiveRestaurantNotifier tenant,
    ProductFormController controller,
  ) {
    if (_categoriesLoaded || tenant.restaurant == null) return;
    _categoriesLoaded = true;
    final restaurant = tenant.restaurant!;
    controller.loadCategoryOptions(
      restaurantId: restaurant.id,
      slug: restaurant.slug,
    );
  }

  void _maybeLoadForEdit(
    ActiveRestaurantNotifier tenant,
    ProductFormController controller,
  ) {
    if (_loadedForEdit || !controller.isEditing || tenant.restaurant == null) {
      return;
    }
    _loadedForEdit = true;
    final restaurant = tenant.restaurant!;
    controller.loadProductForEdit(
      restaurantId: restaurant.id,
      slug: restaurant.slug,
    );
  }

  Future<void> _saveProduct(
    ProductFormController controller,
    ActiveRestaurantNotifier tenant,
  ) async {
    if (_saveLocked || controller.isBusy) return;
    if (!_formKey.currentState!.validate()) return;

    final restaurant = tenant.restaurant;
    if (restaurant == null) return;

    setState(() => _saveLocked = true);

    try {
      await controller.saveProduct(
        restaurantId: restaurant.id,
        slug: restaurant.slug,
      );

      if (!mounted) return;
      controller.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.isEditing ? 'تم تحديث المنتج' : 'تم حفظ المنتج',
          ),
        ),
      );
      context.pop();
    } on ProductFormSaveException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      final fallback =
          controller.errorMessage ?? 'تعذّr حفظ المنتج. حاول مرة أخرى';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallback)),
      );
    } finally {
      if (mounted) {
        setState(() => _saveLocked = false);
      } else {
        _saveLocked = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ActiveRestaurantNotifier, ProductFormController>(
      builder: (context, tenant, controller, _) {
        if (tenant.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (tenant.restaurant == null) {
          return const Center(child: Text('المطعم غير متوفر'));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _maybeLoadCategories(tenant, controller);
          _maybeLoadForEdit(tenant, controller);
        });

        final isBusy = controller.isBusy || _saveLocked;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductImagePickerField(
                  previewBytes: controller.webImage,
                  existingImageUrl: controller.webImage == null
                      ? controller.existingImageUrl
                      : null,
                  isLoading: controller.pickingImage || controller.uploadingImage,
                  loadingLabel: controller.uploadingImage
                      ? 'جاري رفع الصورة إلى Supabase...'
                      : null,
                  onPickPressed: controller.pickFromGallery,
                  onClear: controller.clearPickedImage,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: controller.nameController,
                  textAlign: TextAlign.right,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم الوجبة',
                    border: OutlineInputBorder(),
                  ),
                  validator: ProductFormValidators.validateRequiredName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller.descriptionController,
                  textAlign: TextAlign.right,
                  textInputAction: TextInputAction.next,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller.priceController,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'السعر (د.ع)',
                    border: OutlineInputBorder(),
                  ),
                  validator: ProductFormValidators.validatePositivePrice,
                ),
                const SizedBox(height: 16),
                ProductCategoryField(
                  key: ValueKey(
                    'category-${controller.categoryController.text}-'
                    '${controller.categoryOptions.length}',
                  ),
                  controller: controller.categoryController,
                  categoryOptions: controller.categoryOptions,
                  isLoading: controller.loadingCategories,
                  validator: ProductFormValidators.validateRequiredCategory,
                ),
                const SizedBox(height: 16),
                _AddonsSection(controller: controller),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () => _saveProduct(controller, tenant),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: controller.isBusy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            if (controller.uploadingImage) ...[
                              const SizedBox(width: 12),
                              const Text('جاري رفع الصورة...'),
                            ] else if (controller.saving) ...[
                              const SizedBox(width: 12),
                              const Text('جاري حفظ المنتج...'),
                            ],
                          ],
                        )
                      : Text(
                          controller.isEditing
                              ? 'حفظ التعديلات'
                              : 'حفظ المنتج',
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddonsSection extends StatelessWidget {
  const _AddonsSection({required this.controller});

  final ProductFormController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الإضافات (Add-ons)',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: controller.addAddonDraft,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة خيار'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (controller.addonDrafts.isEmpty)
              const Text(
                'لا توجد إضافات. مثال: خبز إضافي، صوص إضافي.',
                textAlign: TextAlign.right,
              )
            else
              ...controller.addonDrafts.asMap().entries.map((entry) {
                final i = entry.key;
                final draft = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => controller.removeAddonDraftAt(i),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'حذف الإضافة',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: draft.nameController,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'اسم الإضافة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: draft.priceController,
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'السعر',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
