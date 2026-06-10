import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/promo_banner_model.dart';
import '../../services/banner_image_upload_service.dart';
import '../../services/banner_repository.dart';
import '../../state/active_restaurant_notifier.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';

/// إدارة بانرات المنيو التفاعلية.
class BannersAdminScreen extends StatefulWidget {
  const BannersAdminScreen({super.key, required this.slug});

  final String slug;

  @override
  State<BannersAdminScreen> createState() => _BannersAdminScreenState();
}

class _BannersAdminScreenState extends State<BannersAdminScreen> {
  final BannerRepository _repository = BannerRepository();
  final BannerImageUploadService _uploadService = BannerImageUploadService();

  String? _busyBannerId;
  bool _addingBanner = false;

  Future<void> _confirmDelete(PromoBannerModel banner) async {
    if (_busyBannerId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البانر'),
        content: Text(
          banner.title.trim().isEmpty
              ? 'هل تريد حذف هذا البانر؟'
              : 'هل تريد حذف «${banner.title}»؟',
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

    setState(() => _busyBannerId = banner.id);
    try {
      await _repository.deleteBanner(bannerId: banner.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف البانر')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر الحذف: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyBannerId = null);
      } else {
        _busyBannerId = null;
      }
    }
  }

  Future<void> _toggleActive(PromoBannerModel banner, bool value) async {
    if (_busyBannerId != null) return;

    setState(() => _busyBannerId = banner.id);
    try {
      await _repository.setBannerActive(
        bannerId: banner.id,
        isActive: value,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر تحديث الحالة: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyBannerId = null);
      } else {
        _busyBannerId = null;
      }
    }
  }

  Future<void> _addBanner({
    required String restaurantId,
    required String slug,
  }) async {
    if (_addingBanner) return;

    final picked = await _uploadService.pickBannerImageFromGallery();
    if (picked == null || !mounted) return;

    final titleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بانر جديد'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'عنوان البانر (اختياري)',
            hintText: 'مثال: عرض نهاية الأسبوع',
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('رفع'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _addingBanner = true);
    try {
      final bytes = await _uploadService.readAndCompress(picked);
      if (bytes == null || bytes.isEmpty) {
        throw StateError('تعذّر قراءة أو ضغط الصورة');
      }

      await _repository.createBanner(
        restaurantId: restaurantId,
        slug: slug,
        title: titleController.text,
        pickedImageFile: picked,
        pickedImageBytes: bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة البانر')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إضافة البانر: $e')),
      );
    } finally {
      titleController.dispose();
      if (mounted) {
        setState(() => _addingBanner = false);
      } else {
        _addingBanner = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'بانرات المنيو',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addingBanner
            ? null
            : () {
                final restaurant =
                    context.read<ActiveRestaurantNotifier>().restaurant;
                if (restaurant == null) return;
                unawaited(
                  _addBanner(
                    restaurantId: restaurant.id,
                    slug: restaurant.slug,
                  ),
                );
              },
        backgroundColor: AdminPanelColors.gold,
        foregroundColor: AdminPanelColors.charcoal,
        icon: _addingBanner
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AdminPanelColors.charcoal,
                ),
              )
            : const Icon(Icons.add_photo_alternate_rounded),
        label: Text(
          _addingBanner ? 'جاري الرفع…' : 'بانر جديد',
          style: const TextStyle(fontWeight: FontWeight.w800),
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

          return StreamBuilder<List<PromoBannerModel>>(
            stream: _repository.watchAllBanners(
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
                    'تعذّر التحميل: ${snapshot.error}',
                    style: const TextStyle(color: AdminPanelColors.textMuted),
                  ),
                );
              }

              final banners = snapshot.data ?? const [];
              if (banners.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'لا توجد بانرات — اضغط «بانر جديد» لرفع صورة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AdminPanelColors.textMuted.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: banners.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  final isBusy = _busyBannerId == banner.id;

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: AdminPanelColors.gold.withValues(alpha: 0.2),
                      ),
                    ),
                    tileColor: AdminPanelColors.charcoalLight,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        banner.imageUrl,
                        width: 72,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 72,
                          height: 56,
                          color: AdminPanelColors.charcoal,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AdminPanelColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      banner.title.trim().isEmpty
                          ? 'بانر بدون عنوان'
                          : banner.title,
                      style: const TextStyle(
                        color: AdminPanelColors.textLight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      banner.isActive ? 'نشط — يظهر في المنيو' : 'مخفي',
                      style: TextStyle(
                        color: banner.isActive
                            ? AdminPanelColors.gold.withValues(alpha: 0.85)
                            : AdminPanelColors.textMuted,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch.adaptive(
                          value: banner.isActive,
                          activeThumbColor: AdminPanelColors.gold,
                          onChanged: isBusy
                              ? null
                              : (value) => unawaited(_toggleActive(banner, value)),
                        ),
                        IconButton(
                          icon: isBusy
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
                          onPressed: isBusy
                              ? null
                              : () => unawaited(_confirmDelete(banner)),
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
