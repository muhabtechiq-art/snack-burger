import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/promo_banner_model.dart';
import '../../services/banner_image_upload_service.dart';
import '../../services/banner_repository.dart';
import '../../state/active_restaurant_notifier.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
import '../shell/admin_panel_widgets.dart';

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
  Stream<List<PromoBannerModel>>? _bannersStream;
  String? _streamRestaurantId;

  /// حالة مؤكدة بعد نجاح Supabase — حتى يتزامن البث.
  final Map<String, bool> _confirmedActive = {};

  Stream<List<PromoBannerModel>> _bannersStreamFor({
    required String restaurantId,
    required String slug,
  }) {
    if (_streamRestaurantId == restaurantId && _bannersStream != null) {
      return _bannersStream!;
    }
    _streamRestaurantId = restaurantId;
    _bannersStream = _repository.watchAllBanners(
      restaurantId: restaurantId,
      slug: slug,
    );
    return _bannersStream!;
  }

  @override
  void dispose() {
    _bannersStream = null;
    _streamRestaurantId = null;
    super.dispose();
  }

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

  Future<void> _toggleActive(
    PromoBannerModel banner,
    bool value,
  ) async {
    if (_busyBannerId != null) return;

    setState(() => _busyBannerId = banner.id);

    try {
      await _repository.setBannerActive(
        bannerId: banner.id,
        isActive: value,
      );

      if (!mounted) return;

      setState(() {
        _confirmedActive[banner.id] = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'تم تفعيل البانر — سيظهر في المنيو'
                : 'تم إيقاف البانر — لن يظهر في المنيو',
          ),
          backgroundColor: AdminPanelColors.charcoal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirmedActive.remove(banner.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_toggleActiveErrorMessage(e)),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyBannerId = null);
      } else {
        _busyBannerId = null;
      }
    }
  }

  bool _displayBannerActive(PromoBannerModel banner) {
    final confirmed = _confirmedActive[banner.id];
    if (confirmed == null) return banner.isActive;

    if (confirmed == banner.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_confirmedActive[banner.id] == banner.isActive) {
          setState(() => _confirmedActive.remove(banner.id));
        }
      });
    }

    return confirmed;
  }

  String _toggleActiveErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('rls') ||
        raw.contains('لم يُحدَّث أي صف') ||
        raw.contains('banners_rls_fix')) {
      return 'صلاحيات Supabase تمنع التحديث — نفّذ supabase/banners_rls_fix.sql';
    }
    if (raw.contains('permission') || raw.contains('42501')) {
      return 'لا توجد صلاحية لتحديث البانر في Supabase';
    }
    if (raw.contains('pgrst204') || raw.contains('is_active')) {
      return 'عمود is_active غير موجود في جدول banners — راجع schema';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'تعذّر الاتصال — تحقق من الإنترنت وحاول مرة أخرى';
    }
    return 'تعذّر تحديث حالة البانر — حاول مرة أخرى';
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
            stream: _bannersStreamFor(
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
                  final displayActive = _displayBannerActive(banner);

                  return AdminSurfaceCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            banner.imageUrl,
                            width: 88,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 88,
                              height: 64,
                              color: AdminPanelColors.cardLight,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: AdminPanelColors.charcoal
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                banner.title.trim().isEmpty
                                    ? 'بانر بدون عنوان'
                                    : banner.title,
                                style: const TextStyle(
                                  color: AdminPanelColors.charcoal,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: displayActive
                                      ? AdminPanelColors.gold
                                          .withValues(alpha: 0.28)
                                      : AdminPanelColors.charcoal
                                          .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  displayActive
                                      ? 'نشط — يظهر في المنيو'
                                      : 'مخفي',
                                  style: TextStyle(
                                    color: displayActive
                                        ? AdminPanelColors.charcoal
                                        : AdminPanelColors.charcoal
                                            .withValues(alpha: 0.55),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: displayActive,
                          activeThumbColor: AdminPanelColors.gold,
                          onChanged: isBusy
                              ? null
                              : (value) => unawaited(
                                    _toggleActive(banner, value),
                                  ),
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
