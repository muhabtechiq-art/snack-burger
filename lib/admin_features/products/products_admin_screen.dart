import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../state/active_restaurant_notifier.dart';
import '../data/admin_repositories.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

/// صفحة إدارة المنتجات — استعراض وتعديل الأسعار.
class ProductsAdminScreen extends StatefulWidget {
  const ProductsAdminScreen({super.key, required this.slug});

  final String slug;

  @override
  State<ProductsAdminScreen> createState() => _ProductsAdminScreenState();
}

class _ProductsAdminScreenState extends State<ProductsAdminScreen> {
  final AdminProductRepository _productRepository = AdminProductRepository();
  String? _deletingProductId;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف «${product.name}»')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّr حذف المنتج: $e')),
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
        onPressed: () => context.push('/${widget.slug}/admin/products/new'),
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

          return StreamBuilder<List<ProductModel>>(
              stream: _productRepository.watchProducts(
                restaurantId: restaurant.id,
                slug: restaurant.slug,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AdminPanelColors.gold,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'تعذّr التحميل: ${snapshot.error}',
                      style: const TextStyle(color: AdminPanelColors.textMuted),
                    ),
                  );
                }

                final products = snapshot.data ?? const [];
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

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: AdminPanelColors.gold.withValues(alpha: 0.2),
                        ),
                      ),
                      tileColor: AdminPanelColors.charcoalLight,
                      title: Text(
                        product.name,
                        style: const TextStyle(
                          color: AdminPanelColors.textLight,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        product.category.isNotEmpty
                            ? product.category
                            : 'بدون تصنيف',
                        style: const TextStyle(color: AdminPanelColors.textMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${product.price.toStringAsFixed(0)} د.ع',
                            style: const TextStyle(
                              color: AdminPanelColors.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: AdminPanelColors.gold,
                            ),
                            tooltip: 'تعديل',
                            onPressed: isDeleting
                                ? null
                                : () => context.push(
                                      '/${widget.slug}/admin/products/${product.id}/edit',
                                    ),
                          ),
                          IconButton(
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
                    );
                  },
                );
              },
            );
        },
      ),
    );
  }
}
