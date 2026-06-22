-- Phase 1 — ربط orders.restaurant_id ← restaurants.restaurant_uuid (via slug)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
-- يتطلب: restaurants.restaurant_uuid موجود ومُعبّأ (restaurants_restaurant_uuid_migration.sql)
--
-- لا يغيّر: restaurants.id · orders.slug · Flutter · RPC · RLS
-- orders.restaurant_id = uuid — لا تستخدم trim/btrim على uuid

-- =============================================================================
-- 0) نسخة احتياطية اختيارية للـ rollback (لا تحذف طلبات)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.orders_restaurant_id_backfill_backup (
  order_id bigint PRIMARY KEY,
  restaurant_id uuid,
  backed_up_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.orders_restaurant_id_backfill_backup (order_id, restaurant_id)
SELECT o.id, o.restaurant_id
FROM public.orders o
WHERE NOT EXISTS (
  SELECT 1
  FROM public.orders_restaurant_id_backfill_backup b
  WHERE b.order_id = o.id
);

-- =============================================================================
-- 1) Backfill: restaurant_id ← restaurant_uuid عند تطابق slug
--    - يحدّث فقط restaurant_id IS NULL
--    - يتخطى slug NULL أو فارغ
-- =============================================================================
UPDATE public.orders o
SET restaurant_id = r.restaurant_uuid
FROM public.restaurants r
WHERE o.restaurant_id IS NULL
  AND o.slug IS NOT NULL
  AND btrim(o.slug) <> ''
  AND lower(btrim(o.slug)) = lower(btrim(r.slug))
  AND r.restaurant_uuid IS NOT NULL;

-- =============================================================================
-- 2) فهرس على orders.restaurant_id
-- =============================================================================
CREATE INDEX IF NOT EXISTS orders_restaurant_id_idx
  ON public.orders (restaurant_id)
  WHERE restaurant_id IS NOT NULL;

-- =============================================================================
-- 3) تحقق بعد التنفيذ
-- =============================================================================
SELECT
  count(*) AS total_orders,
  count(*) FILTER (WHERE restaurant_id IS NULL) AS missing_restaurant_id,
  count(*) FILTER (WHERE slug IS NULL OR btrim(slug) = '') AS missing_slug,
  count(*) FILTER (WHERE restaurant_id IS NOT NULL) AS linked_orders
FROM public.orders;

-- =============================================================================
-- 4) عينة — آخر 10 طلبات
-- =============================================================================
SELECT
  id,
  slug,
  restaurant_id,
  business_day_id,
  status,
  created_at
FROM public.orders
ORDER BY created_at DESC NULLS LAST, id DESC
LIMIT 10;

-- =============================================================================
-- ROLLBACK آمن (لا يحذف الطلبات — يستعيد restaurant_id من النسخة الاحتياطية)
-- =============================================================================
-- UPDATE public.orders o
-- SET restaurant_id = b.restaurant_id
-- FROM public.orders_restaurant_id_backfill_backup b
-- WHERE o.id = b.order_id;
--
-- DROP INDEX IF EXISTS public.orders_restaurant_id_idx;
--
-- -- اختياري: حذف جدول النسخة الاحتياطية بعد التأكد
-- -- DROP TABLE IF EXISTS public.orders_restaurant_id_backfill_backup;

NOTIFY pgrst, 'reload schema';
