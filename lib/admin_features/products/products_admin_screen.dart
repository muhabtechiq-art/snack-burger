import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
import '../shell/admin_panel_widgets.dart';
import 'products_admin_controller.dart';

/// صفحة إدارة المنتجات — استعراض وتعديل الأسعار.
class ProductsAdminScreen extends StatefulWidget {
  const ProductsAdminScreen({super.key, required this.slug});

  final String slug;

  @override
  State<ProductsAdminScreen> createState() => _ProductsAdminScreenState();
}

class _ProductsAdminScreenState extends State<ProductsAdminScreen>
    with WidgetsBindingObserver {
  final AdminProductRepository _productRepository = AdminProductRepository();
  late final ProductsAdminController _productsController;

  String? _deletingProductId;
  String? _boundRestaurantKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _productsController = ProductsAdminController(
      repository: _productRepository,
      onRealtimeDegraded: _showRealtimeDegradedToast,
    );
    _productsController.addListener(_onProductsControllerChanged);
  }

  void _onProductsControllerChanged() {
    if (mounted) setState(() {});
  }

  void _showRealtimeDegradedToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم تحميل البيانات، المزامنة المباشرة ستعود تلقائياً',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: AdminPanelColors.charcoalLight,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _productsController.handleLifecycleState(state);
  }

  void _bindProductsIfNeeded({
    required String restaurantId,
    required String slug,
  }) {
    final key = '$restaurantId|$slug';
    if (_boundRestaurantKey == key) return;
    _boundRestaurantKey = key;
    unawaited(_productsController.bind(restaurantId: restaurantId, slug: slug));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _productsController.removeListener(_onProductsControllerChanged);
    _productsController.dispose();
    super.dispose();
  }

  Future<void> _openNewProduct(BuildContext context) async {
    await context.push('/${widget.slug}/admin/products/new');
    if (!mounted) return;
    await _productsController.loadProducts();
  }

  Future<void> _openEditProduct(BuildContext context, String productId) async {
    await context.push('/${widget.slug}/admin/products/$productId/edit');
    if (!mounted) return;
    await _productsController.loadProducts();
  }

  Future<void> _confirmDeleteProduct(ProductModel product) async {
    if (_deletingProductId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text(
          'هل تريد حذف «${product.name}»؟\n'
          'سيتم حذف الإضافات المرتبطة به أيضاً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingProductId = product.id);

    try {
      await _productRepository.deleteProduct(productId: product.id);
      if (!mounted) return;
      await _productsController.loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف «${product.name}»')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر حذف المنتج: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingProductId = null);
      } else {
        _deletingProductId = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'إدارة المنتجات',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewProduct(context),
        backgroundColor: AdminPanelColors.gold,
        foregroundColor: AdminPanelColors.charcoal,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'وجبة جديدة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<ActiveRestaurantNotifier>(
        builder: (context, tenant, _) {
          final restaurant = tenant.restaurant;
          if (restaurant == null) {
            return const Center(
              child: CircularProgressIndicator(color: AdminPanelColors.gold),
            );
          }

          _bindProductsIfNeeded(
            restaurantId: restaurant.id,
            slug: restaurant.slug,
          );

          if (_productsController.loading && !_productsController.hasProducts) {
            return const Center(
              child: CircularProgressIndicator(
                color: AdminPanelColors.gold,
              ),
            );
          }

          final products = _productsController.products;
          if (products.isEmpty) {
            return Center(
              child: Text(
                'لا توجد منتجات — أضف وجبة جديدة',
                style: TextStyle(
                  color: AdminPanelColors.textMuted.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              final isDeleting = _deletingProductId == product.id;

              return AdminSurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ProductImagePreview(imageUrl: product.imageUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AdminPanelColors.charcoal,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.category.isNotEmpty
                                ? product.category
                                : 'بدون تصنيف',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AdminPanelColors.charcoal
                                  .withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(0)} د.ع',
                          style: const TextStyle(
                            color: AdminPanelColors.charcoal,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              icon: const Icon(
                                Icons.edit_rounded,
                                color: AdminPanelColors.gold,
                              ),
                              tooltip: 'تعديل',
                              onPressed: isDeleting
                                  ? null
                                  : () =>
                                      _openEditProduct(context, product.id),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              icon: isDeleting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.redAccent,
                                      ),
                                    )
                                  : Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red.shade400,
                                    ),
                              tooltip: 'حذف',
                              onPressed: isDeleting
                                  ? null
                                  : () => _confirmDeleteProduct(product),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductImagePreview extends StatelessWidget {
  const _ProductImagePreview({required this.imageUrl});

  static const _size = 56.0;

  final String? imageUrl;

  bool get _hasValidUrl {
    final trimmed = imageUrl?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidUrl) {
      return const _ProductNoImageBadge();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Image.network(
          imageUrl!.trim(),
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AdminPanelColors.cardLight,
              alignment: Alignment.center,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AdminPanelColors.gold.withValues(alpha: 0.85),
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) => const _ProductNoImageBadge(),
        ),
      ),
    );
  }
}

class _ProductNoImageBadge extends StatelessWidget {
  const _ProductNoImageBadge();

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AdminPanelColors.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AdminPanelColors.gold.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hide_image_outlined,
            size: 18,
            color: Colors.orange.shade800.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 2),
          Text(
            'بدون صورة',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.orange.shade900.withValues(alpha: 0.88),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
