-- صوت اليوم — أعمدة إعدادات التطبيق
-- نفّذ يدوياً في: Supabase Dashboard → SQL Editor
--
-- يضيف حقول صوت اليوم إلى جدول app_settings الموجود.

ALTER TABLE public.app_settings
  ADD COLUMN IF NOT EXISTS daily_sound_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS daily_sound_url text,
  ADD COLUMN IF NOT EXISTS daily_sound_title text,
  ADD COLUMN IF NOT EXISTS daily_sound_volume numeric NOT NULL DEFAULT 0.3,
  ADD COLUMN IF NOT EXISTS daily_sound_loop boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.app_settings.daily_sound_enabled IS 'تفعيل زر صوت اليوم في واجهة الزبون';
COMMENT ON COLUMN public.app_settings.daily_sound_url IS 'رابط عام لملف الصوت في Storage';
COMMENT ON COLUMN public.app_settings.daily_sound_title IS 'اسم الملف المعروض في لوحة الإدارة';
COMMENT ON COLUMN public.app_settings.daily_sound_volume IS 'مستوى الصوت الافتراضي 0.0–1.0';
COMMENT ON COLUMN public.app_settings.daily_sound_loop IS 'true = تكرار، false = مرة واحدة';
