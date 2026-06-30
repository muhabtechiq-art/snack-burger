import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/promo_banner_model.dart';
import '../../services/banner_image_upload_service.dart';
import '../../services/image_upload_exception.dart';
import '../shell/admin_panel_colors.dart';

/// نتيجة نموذج إضافة/تعديل البانر.
class BannerFormDialogResult {
  const BannerFormDialogResult({
    required this.title,
    required this.isActive,
    required this.sortOrder,
    this.newImageFile,
    this.newImageBytes,
    this.imageChanged = false,
  });

  final String title;
  final bool isActive;
  final int sortOrder;

  /// صورة جديدة — مطلوبة عند الإنشاء، اختيارية عند التعديل.
  final XFile? newImageFile;
  final Uint8List? newImageBytes;
  final bool imageChanged;
}

/// يحلّل حقل الترتيب — قيمة سالبة أو غير رقمية تُعاد إلى 0.
int parseBannerSortOrder(String raw) {
  final parsed = int.tryParse(raw.trim());
  if (parsed == null || parsed < 0) return 0;
  return parsed;
}

/// نموذج مشترك لإضافة بانر جديد أو تعديل بانر موجود.
Future<BannerFormDialogResult?> showBannerFormDialog({
  required BuildContext context,
  required BannerImageUploadService uploadService,
  PromoBannerModel? banner,
  XFile? initialImage,
  int initialSortOrder = 0,
}) {
  final isEdit = banner != null;
  return showDialog<BannerFormDialogResult>(
    context: context,
    barrierDismissible: !isEdit,
    builder: (context) => _BannerFormDialog(
      uploadService: uploadService,
      banner: banner,
      initialImage: initialImage,
      initialSortOrder: initialSortOrder,
    ),
  );
}

class _BannerFormDialog extends StatefulWidget {
  const _BannerFormDialog({
    required this.uploadService,
    this.banner,
    this.initialImage,
    this.initialSortOrder = 0,
  });

  final BannerImageUploadService uploadService;
  final PromoBannerModel? banner;
  final XFile? initialImage;
  final int initialSortOrder;

  bool get isEdit => banner != null;

  @override
  State<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends State<_BannerFormDialog> {
  late final TextEditingController _titleController;
  late final int _sortOrder;
  late bool _isActive;
  XFile? _pickedImage;
  Uint8List? _previewBytes;
  Uint8List? _uploadBytes;
  bool _imageChanged = false;
  bool _pickingImage = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final banner = widget.banner;
    _titleController = TextEditingController(text: banner?.title ?? '');
    _sortOrder = banner?.sortOrder ?? widget.initialSortOrder;
    _isActive = banner?.isActive ?? true;
    _pickedImage = widget.initialImage;
    if (_pickedImage != null) {
      _imageChanged = true;
      unawaited(_loadPreviewWithLoading(_pickedImage!));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _setPickingImage(bool value) {
    if (_pickingImage == value) return;
    setState(() => _pickingImage = value);
  }

  Future<void> _loadPreviewWithLoading(XFile file) async {
    if (_saving || _pickingImage) return;

    _setPickingImage(true);
    try {
      await _loadPreviewBytes(file);
    } finally {
      if (mounted) _setPickingImage(false);
    }
  }

  Future<void> _loadPreviewBytes(XFile file) async {
    final result = await widget.uploadService.prepareBannerImagePreview(file);
    if (!mounted) return;

    if (result == null || result.previewBytes.isEmpty) {
      setState(() => _errorMessage = 'تعذّر قراءة ملف الصورة. جرّب صورة أخرى');
      return;
    }

    if (result.usedFallback) {
      debugPrint(
        '[BannerFormDialog] WARNING banner preview uses uncompressed fallback',
      );
    }

    setState(() {
      _previewBytes = result.previewBytes;
      _uploadBytes = null;
    });
  }

  Future<void> _pickNewImage() async {
    if (_saving || _pickingImage) return;

    _setPickingImage(true);
    try {
      final picked = await widget.uploadService.pickBannerImageFromGallery();
      if (!mounted) return;

      if (picked == null) {
        return;
      }

      setState(() {
        _pickedImage = picked;
        _imageChanged = true;
        _previewBytes = null;
        _uploadBytes = null;
        _errorMessage = null;
      });

      await _loadPreviewBytes(picked);
    } on ImageUploadException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e, st) {
      debugPrint('BannerFormDialog._pickNewImage: $e\n$st');
      if (mounted) {
        setState(() => _errorMessage = 'تعذّر اختيار الصورة. حاول مرة أخرى');
      }
    } finally {
      if (mounted) _setPickingImage(false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!widget.isEdit && _pickedImage == null) {
      setState(() => _errorMessage = 'اختر صورة للبانر');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      Uint8List? bytes = _uploadBytes;
      if (_imageChanged && _pickedImage != null) {
        if (bytes == null || bytes.isEmpty) {
          bytes = await widget.uploadService.readAndCompress(_pickedImage!);
          if (!mounted) return;
          if (bytes == null || bytes.isEmpty) {
            throw StateError('تعذّر قراءة أو ضغط الصورة');
          }
          _uploadBytes = bytes;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        BannerFormDialogResult(
          title: _titleController.text,
          isActive: _isActive,
          sortOrder: _sortOrder,
          newImageFile: _imageChanged ? _pickedImage : null,
          newImageBytes: _imageChanged ? bytes : null,
          imageChanged: _imageChanged,
        ),
      );
    } on ImageUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'تعذّر تجهيز الصورة — حاول مرة أخرى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;
    final title = widget.isEdit ? 'تعديل البانر' : 'بانر جديد';
    final submitLabel = widget.isEdit ? 'حفظ التعديل' : 'رفع';

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImagePreview(banner),
                    if (_pickingImage)
                      ColoredBox(
                        color: AdminPanelColors.charcoal.withValues(alpha: 0.35),
                        child: const Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AdminPanelColors.gold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving || _pickingImage ? null : _pickNewImage,
              icon: _pickingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AdminPanelColors.charcoal,
                      ),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(
                widget.isEdit && !_imageChanged
                    ? 'تغيير الصورة'
                    : 'اختيار صورة',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminPanelColors.charcoal,
                side: BorderSide(
                  color: AdminPanelColors.gold.withValues(alpha: 0.55),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              enabled: !_saving && !_pickingImage,
              decoration: const InputDecoration(
                labelText: 'عنوان البانر (اختياري)',
                hintText: 'مثال: عرض نهاية الأسبوع',
              ),
              textInputAction: TextInputAction.done,
            ),
            if (widget.isEdit) ...[
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'الترتيب',
                ),
                child: Text(
                  'يُعدَّل بالسحب من قائمة البانرات (الحالي: $_sortOrder)',
                  style: TextStyle(
                    color: AdminPanelColors.charcoal.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('نشط — يظهر في المنيو'),
              value: _isActive,
              activeThumbColor: AdminPanelColors.gold,
              onChanged: _saving || _pickingImage
                  ? null
                  : (value) => setState(() => _isActive = value),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving || _pickingImage ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving || _pickingImage ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AdminPanelColors.gold,
            foregroundColor: AdminPanelColors.charcoal,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AdminPanelColors.charcoal,
                  ),
                )
              : Text(
                  submitLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(PromoBannerModel? banner) {
    if (_previewBytes != null && _previewBytes!.isNotEmpty) {
      return Image.memory(
        _previewBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: BannerImageUploadService.previewMaxWidth,
      );
    }

    if (banner != null && !_imageChanged && banner.imageUrl.trim().isNotEmpty) {
      return Image.network(
        banner.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      );
    }

    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AdminPanelColors.cardLight,
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: AdminPanelColors.charcoal.withValues(alpha: 0.4),
      ),
    );
  }
}
