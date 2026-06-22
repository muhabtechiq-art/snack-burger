-- Migration انتقالية: restaurants.restaurant_uuid (UUID)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
-- آمن للتشغيل المتكرر — لا يغيّر id ولا slug ولا يحذف أعمدة

-- =============================================================================
-- 0) UUID generation (Supabase: gen_random_uuid() متاح عادةً)
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================================================
-- 1) إضافة العمود (nullable أولاً — آمن للبيانات الموجودة)
-- =============================================================================
ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS restaurant_uuid uuid;

COMMENT ON COLUMN public.restaurants.restaurant_uuid IS
  'معرّف UUID ثابت للمطعم — انتقالي؛ restaurants.id (text) يبقى كما هو';

-- =============================================================================
-- 2) تعبئة تلقائية لكل صف بدون restaurant_uuid
-- =============================================================================
UPDATE public.restaurants
SET restaurant_uuid = gen_random_uuid()
WHERE restaurant_uuid IS NULL;

-- =============================================================================
-- 3) NOT NULL — بعد التأكد من عدم وجود NULL
-- =============================================================================
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.restaurants
    WHERE restaurant_uuid IS NULL
  ) THEN
    RAISE EXCEPTION
      'restaurants_restaurant_uuid_migration: cannot SET NOT NULL — rows with NULL restaurant_uuid remain';
  END IF;
END $$;

ALTER TABLE public.restaurants
  ALTER COLUMN restaurant_uuid SET NOT NULL;

-- =============================================================================
-- 4) UNIQUE + DEFAULT للصفوف الجديدة
-- =============================================================================
ALTER TABLE public.restaurants
  ALTER COLUMN restaurant_uuid SET DEFAULT gen_random_uuid();

CREATE UNIQUE INDEX IF NOT EXISTS restaurants_restaurant_uuid_uq
  ON public.restaurants (restaurant_uuid);

-- =============================================================================
-- 5) تحقق بعد التنفيذ
-- =============================================================================
SELECT
  id,
  slug,
  restaurant_uuid,
  name
FROM public.restaurants
ORDER BY slug;

-- =============================================================================
-- ROLLBACK آمن (نفّذ يدوياً فقط عند الحاجة — يحذف العمود الجديد فقط)
-- =============================================================================
-- DROP INDEX IF EXISTS public.restaurants_restaurant_uuid_uq;
-- ALTER TABLE public.restaurants DROP COLUMN IF EXISTS restaurant_uuid;

NOTIFY pgrst, 'reload schema';
