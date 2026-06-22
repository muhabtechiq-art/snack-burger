-- Phase 1 — Step 1: orders.restaurant_id + backfill من restaurants.slug
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor (قبل أو مع submit_customer_order_rpc.sql)
-- آمن للتشغيل المتكرر — لا يحذف طلبات ولا يغيّر business_day_id
--
-- ملاحظة: orders.restaurant_id قد يكون uuid أو text حسب البيئة.
-- لا تستخدم trim/btrim مباشرة على uuid — استخدم IS NULL أو ::text قبل btrim.

-- =============================================================================
-- 1) التأكد من وجود الأعمدة (slug + restaurant_id)
--    ADD COLUMN IF NOT EXISTS لا يغيّر نوع عمود موجود (مثلاً uuid).
-- =============================================================================
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS restaurant_id text,
  ADD COLUMN IF NOT EXISTS slug text;

COMMENT ON COLUMN public.orders.restaurant_id IS
  'معرّف المطعم — uuid أو text — يُملأ عند submit_customer_order';

COMMENT ON COLUMN public.orders.slug IS
  'slug المطعم في الرابط — يُملأ عند submit_customer_order من p_slug';

-- =============================================================================
-- 2) Backfill — يكتشف نوع orders.restaurant_id وينفّذ UPDATE المناسب
--    - uuid:  WHERE restaurant_id IS NULL فقط (بدون trim على uuid)
--    - text:  WHERE restaurant_id IS NULL OR btrim(restaurant_id::text) = ''
--    - SET:   uuid ← r.id::uuid (إذا id بصيغة UUID)
--             text ← r.id::text
-- =============================================================================
DO $$
DECLARE
  v_restaurant_id_udt text;
  v_rows_slug_match integer;
  v_rows_id_match integer;
BEGIN
  SELECT c.udt_name
  INTO v_restaurant_id_udt
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'orders'
    AND c.column_name = 'restaurant_id';

  IF v_restaurant_id_udt IS NULL THEN
    RAISE NOTICE 'phase1 backfill: orders.restaurant_id not found — skipped';
    RETURN;
  END IF;

  IF v_restaurant_id_udt = 'uuid' THEN
    -- مطابقة orders.slug ↔ restaurants.slug
    UPDATE public.orders o
    SET restaurant_id = r.id::uuid
    FROM public.restaurants r
    WHERE o.restaurant_id IS NULL
      AND o.slug IS NOT NULL
      AND btrim(o.slug) <> ''
      AND lower(btrim(o.slug)) = lower(btrim(r.slug))
      AND r.id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

    GET DIAGNOSTICS v_rows_slug_match = ROW_COUNT;

    -- مطابقة orders.slug ↔ restaurants.id (نص UUID)
    UPDATE public.orders o
    SET restaurant_id = r.id::uuid
    FROM public.restaurants r
    WHERE o.restaurant_id IS NULL
      AND o.slug IS NOT NULL
      AND btrim(o.slug) <> ''
      AND lower(btrim(o.slug)) = lower(btrim(r.id::text))
      AND r.id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

    GET DIAGNOSTICS v_rows_id_match = ROW_COUNT;

    RAISE NOTICE 'phase1 backfill (uuid): updated by slug=% , by id=%',
      v_rows_slug_match, v_rows_id_match;
  ELSE
    -- text (أو char/varchar)
    UPDATE public.orders o
    SET restaurant_id = btrim(r.id::text)
    FROM public.restaurants r
    WHERE (o.restaurant_id IS NULL OR btrim(o.restaurant_id::text) = '')
      AND o.slug IS NOT NULL
      AND btrim(o.slug) <> ''
      AND lower(btrim(o.slug)) = lower(btrim(r.slug));

    GET DIAGNOSTICS v_rows_slug_match = ROW_COUNT;

    UPDATE public.orders o
    SET restaurant_id = btrim(r.id::text)
    FROM public.restaurants r
    WHERE (o.restaurant_id IS NULL OR btrim(o.restaurant_id::text) = '')
      AND o.slug IS NOT NULL
      AND btrim(o.slug) <> ''
      AND lower(btrim(o.slug)) = lower(btrim(r.id::text));

    GET DIAGNOSTICS v_rows_id_match = ROW_COUNT;

    RAISE NOTICE 'phase1 backfill (text): updated by slug=% , by id=%',
      v_rows_slug_match, v_rows_id_match;
  END IF;
END $$;

-- =============================================================================
-- 3) فهارس — uuid أو text
-- =============================================================================
CREATE INDEX IF NOT EXISTS orders_restaurant_id_idx
  ON public.orders (restaurant_id)
  WHERE restaurant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS orders_slug_idx
  ON public.orders (slug)
  WHERE slug IS NOT NULL;

-- =============================================================================
-- 4) تحقق سريع (للمراجعة بعد التنفيذ — لا يغيّر بيانات)
--    آمن لـ uuid و text: cast إلى text قبل btrim
-- =============================================================================
-- SELECT
--   count(*) FILTER (
--     WHERE restaurant_id IS NULL
--        OR btrim(restaurant_id::text) = ''
--   ) AS missing_restaurant_id,
--   count(*) FILTER (
--     WHERE slug IS NULL OR btrim(slug) = ''
--   ) AS missing_slug,
--   count(*) AS total_orders
-- FROM public.orders;

NOTIFY pgrst, 'reload schema';
