-- Business Day — وقت انتهاء يوم العمل (يُنفَّذ يدوياً في Supabase SQL Editor)
-- آمن للتشغيل المتكرر — لا يحذف بيانات

ALTER TABLE public.app_settings
  ADD COLUMN IF NOT EXISTS business_day_closing_time time NOT NULL DEFAULT '02:00:00';

COMMENT ON COLUMN public.app_settings.business_day_closing_time IS
  'وقت إغلاق يوم العمل المحلي — الطلبات قبل هذا الوقت تُحسب ضمن يوم العمل السابق';

UPDATE public.app_settings
SET business_day_closing_time = COALESCE(business_day_closing_time, '02:00:00'::time)
WHERE id = 'global';

NOTIFY pgrst, 'reload schema';
