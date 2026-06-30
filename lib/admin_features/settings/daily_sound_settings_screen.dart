import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_settings_model.dart';
import '../../services/daily_sound_upload_service.dart';
import '../../state/app_settings_notifier.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
import '../shell/admin_panel_widgets.dart';

/// إعدادات صوت اليوم — رفع ملف صوتي اختياري للزبائن.
class DailySoundSettingsScreen extends StatefulWidget {
  const DailySoundSettingsScreen({super.key, required this.slug});

  final String slug;

  @override
  State<DailySoundSettingsScreen> createState() =>
      _DailySoundSettingsScreenState();
}

class _DailySoundSettingsScreenState extends State<DailySoundSettingsScreen> {
  final DailySoundUploadService _uploadService = DailySoundUploadService();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  bool _enabled = false;
  bool _loop = false;
  int _volumePercent = 30;

  String _soundUrl = '';
  String _soundTitle = '';
  String? _pendingDeleteUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final settings = context.read<AppSettingsNotifier>().settings;
      _applyToForm(settings);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyToForm(AppSettingsModel settings) {
    _enabled = settings.dailySoundEnabled;
    _loop = settings.dailySoundLoop;
    _volumePercent = (settings.dailySoundVolume * 100).round().clamp(0, 100);
    _soundUrl = settings.dailySoundUrl;
    _soundTitle = settings.dailySoundTitle;
    _pendingDeleteUrl = null;
  }

  Future<void> _pickAndUpload() async {
    if (_uploading || _saving) return;

    setState(() => _uploading = true);
    try {
      final picked = await _uploadService.pickAudioFile();
      if (picked == null) return;

      final uploaded = await _uploadService.uploadDailySound(
        restaurantSlug: widget.slug,
        bytes: picked.bytes,
        fileName: picked.fileName,
      );

      if (_soundUrl.isNotEmpty && _soundUrl != uploaded.publicUrl) {
        _pendingDeleteUrl ??= _soundUrl;
      }

      if (!mounted) return;
      setState(() {
        _soundUrl = uploaded.publicUrl;
        _soundTitle = uploaded.fileName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع الملف — اضغط «حفظ الإعدادات»')),
      );
    } on DailySoundUploadException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر رفع الملف: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeCurrentSound() async {
    if (_soundUrl.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الصوت'),
        content: const Text('هل تريد حذف ملف صوت اليوم الحالي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _pendingDeleteUrl = _soundUrl;
    setState(() {
      _soundUrl = '';
      _soundTitle = '';
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_enabled && _soundUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ارفع ملفاً صوتياً قبل تفعيل صوت اليوم'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = context.read<AppSettingsNotifier>();
      final saved = await notifier.saveDailySoundSettings(
        dailySoundEnabled: _enabled,
        dailySoundUrl: _soundUrl,
        dailySoundTitle: _soundTitle,
        dailySoundVolume: _volumePercent / 100,
        dailySoundLoop: _loop,
      );

      final deleteUrl = _pendingDeleteUrl;
      if (deleteUrl != null && deleteUrl.isNotEmpty) {
        await _uploadService.deleteByPublicUrl(deleteUrl);
      }

      if (!mounted) return;
      _applyToForm(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات صوت اليوم')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر حفظ الإعدادات: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _uploading;

    return AdminPageScaffold(
      slug: widget.slug,
      title: 'صوت اليوم',
      titleIcon: Icons.volume_up_rounded,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AdminPanelColors.loginGradient),
        child: SafeArea(
          top: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AdminPanelColors.gold),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminSurfaceCard(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'تفعيل صوت اليوم',
                            style: TextStyle(
                              color: AdminPanelColors.charcoal,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Text(
                            _enabled
                                ? 'سيظهر زر 🔊 للزبائن في المنيو'
                                : 'مخفي عن الزبائن',
                            style: TextStyle(
                              color: AdminPanelColors.charcoal
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                          value: _enabled,
                          activeThumbColor: AdminPanelColors.gold,
                          onChanged: busy
                              ? null
                              : (value) => setState(() => _enabled = value),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AdminSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'ملف الصوت',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AdminPanelColors.charcoal,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _soundTitle.isNotEmpty
                                  ? _soundTitle
                                  : 'لا يوجد ملف مرفوع',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AdminPanelColors.charcoal
                                    .withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _pickAndUpload,
                                  icon: _uploading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.upload_file_rounded),
                                  label: Text(
                                    _soundUrl.isEmpty
                                        ? 'رفع ملف صوتي'
                                        : 'استبدال الملف',
                                  ),
                                ),
                                if (_soundUrl.isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: busy ? null : _removeCurrentSound,
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    label: const Text('حذف الصوت'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الصيغ المدعومة: mp3, m4a, aac — ${DailySoundUploadService.maxSizeMessage}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: AdminPanelColors.charcoal
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      AdminSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'مستوى الصوت الافتراضي: $_volumePercent%',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AdminPanelColors.charcoal,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Slider(
                              value: _volumePercent.toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 20,
                              label: '$_volumePercent%',
                              activeColor: AdminPanelColors.gold,
                              onChanged: busy
                                  ? null
                                  : (value) => setState(
                                        () => _volumePercent = value.round(),
                                      ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      AdminSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'طريقة التشغيل',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AdminPanelColors.charcoal,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('تكرار الصوت'),
                              subtitle: Text(
                                _loop
                                    ? 'يُعاد تشغيل الملف تلقائياً'
                                    : 'يُشغَّل مرة واحدة فقط',
                                style: TextStyle(
                                  color: AdminPanelColors.charcoal
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              value: _loop,
                              activeThumbColor: AdminPanelColors.gold,
                              onChanged: busy
                                  ? null
                                  : (value) => setState(() => _loop = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: busy ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text('حفظ الإعدادات'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminPanelColors.gold,
                          foregroundColor: AdminPanelColors.charcoal,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
