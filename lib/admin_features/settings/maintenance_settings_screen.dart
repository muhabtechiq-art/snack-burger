import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_settings_model.dart';
import '../../state/app_settings_notifier.dart';
import '../shell/admin_page_scaffold.dart';
import '../shell/admin_panel_colors.dart';
import '../shell/admin_panel_widgets.dart';

/// إعدادات وضع الصيانة — تشغيل/إيقاف ورسالة الاعتذار وأرقام الهاتف.
class MaintenanceSettingsScreen extends StatefulWidget {
  const MaintenanceSettingsScreen({super.key, required this.slug});

  final String slug;

  @override
  State<MaintenanceSettingsScreen> createState() =>
      _MaintenanceSettingsScreenState();
}

class _MaintenanceSettingsScreenState extends State<MaintenanceSettingsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();

  bool _maintenanceMode = false;
  bool _loading = true;
  bool _saving = false;

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
    _maintenanceMode = settings.maintenanceMode;
    _titleController.text = settings.maintenanceTitle;
    _messageController.text = settings.maintenanceMessage;
    _phone1Controller.text = settings.phone1;
    _phone2Controller.text = settings.phone2;
  }

  AppSettingsModel _buildFromForm(AppSettingsModel current) {
    return current.copyWith(
      maintenanceMode: _maintenanceMode,
      maintenanceTitle: _titleController.text.trim(),
      maintenanceMessage: _messageController.text.trim(),
      phone1: _phone1Controller.text.trim(),
      phone2: _phone2Controller.text.trim(),
    );
  }

  Future<void> _save({bool? maintenanceMode}) async {
    if (_saving) return;
    if (maintenanceMode != null) {
      setState(() => _maintenanceMode = maintenanceMode);
    }

    setState(() => _saving = true);
    try {
      final notifier = context.read<AppSettingsNotifier>();
      final saved = await notifier.saveSettings(
        _buildFromForm(notifier.settings),
      );
      if (!mounted) return;
      _applyToForm(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.maintenanceMode
                ? 'تم تفعيل وضع الصيانة — الزبائن لن يروا المنيو'
                : 'تم إيقاف وضع الصيانة — الخدمة عادت للزبائن',
          ),
        ),
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
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      slug: widget.slug,
      title: 'وضع الصيانة',
      titleIcon: Icons.construction_rounded,
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
                            'وضع الصيانة',
                            style: TextStyle(
                              color: AdminPanelColors.charcoal,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Text(
                            _maintenanceMode
                                ? 'الزبائن يرون شاشة الاعتذار — لوحة الإدارة تعمل'
                                : 'الخدمة طبيعية للزبائن',
                            style: TextStyle(
                              color: AdminPanelColors.charcoal
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                          value: _maintenanceMode,
                          activeThumbColor: AdminPanelColors.gold,
                          onChanged: _saving
                              ? null
                              : (value) => _save(maintenanceMode: value),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AdminSurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'رسالة الصيانة',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AdminPanelColors.charcoal,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _field(
                              controller: _titleController,
                              label: 'العنوان',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),
                            _field(
                              controller: _messageController,
                              label: 'نص الاعتذار',
                              maxLines: 6,
                            ),
                            const SizedBox(height: 10),
                            _field(
                              controller: _phone1Controller,
                              label: 'الهاتف الأول',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 10),
                            _field(
                              controller: _phone2Controller,
                              label: 'الهاتف الثاني',
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _saving ? null : () => _save(),
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AdminPanelColors.charcoal,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _saving ? 'جاري الحفظ...' : 'حفظ الإعدادات',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AdminPanelColors.gold,
                                foregroundColor: AdminPanelColors.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: AdminPanelColors.charcoal,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
