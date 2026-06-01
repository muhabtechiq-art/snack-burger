-- أعمدة التوصيل لجدول orders — نفّذ يدوياً في Supabase → SQL Editor
-- (لا يُنفَّذ من التطبيق)

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS restaurant_id text,
  ADD COLUMN IF NOT EXISTS slug text,
  ADD COLUMN IF NOT EXISTS location_coordinates text,
  ADD COLUMN IF NOT EXISTS delivery_driver_id text;

COMMENT ON COLUMN public.orders.location_coordinates IS
  'إحداثيات GPS بصيغة lat,long';

COMMENT ON COLUMN public.orders.restaurant_id IS
  'UUID المطعم — nullable حتى ربط المطاعم بجدول restaurants';

-- status يدعم: pending, accepted, rejected, delivering, delivered

NOTIFY pgrst, 'reload schema';
