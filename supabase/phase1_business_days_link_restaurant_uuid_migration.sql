-- Phase 1 — ربط business_days.restaurant_id بجدول restaurants (via slug)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- يفحص نوع business_days.restaurant_id أولاً:
--   TEXT  → UPDATE من restaurants.id فقط (لا UUID)
--   UUID  → UPDATE من restaurants.restaurant_uuid فقط
-- لا يوجد أي مقارنة text = uuid

-- =============================================================================
-- 0) فحص نوع العمود
-- =============================================================================
SELECT
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name = 'business_days'
  AND c.column_name = 'restaurant_id';

-- =============================================================================
-- 1) Backup قبل أي UPDATE
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.business_days_restaurant_id_backfill_backup (
  business_day_id uuid PRIMARY KEY,
  restaurant_id_backup text,
  column_udt_name text NOT NULL,
  backed_up_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.business_days_restaurant_id_backfill_backup (
  business_day_id,
  restaurant_id_backup,
  column_udt_name
)
SELECT
  bd.id,
  bd.restaurant_id::text,
  (
    SELECT c.udt_name
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'business_days'
      AND c.column_name = 'restaurant_id'
  )
FROM public.business_days bd
WHERE NOT EXISTS (
  SELECT 1
  FROM public.business_days_restaurant_id_backfill_backup b
  WHERE b.business_day_id = bd.id
);

-- =============================================================================
-- 2) جداول مؤقتة للتقرير والتحقق (تُملأ حسب نوع العمود)
-- =============================================================================
DROP TABLE IF EXISTS pg_temp.phase1_bd_link_report;
CREATE TEMP TABLE pg_temp.phase1_bd_link_report (
  business_day_id uuid,
  business_day_slug text,
  current_restaurant_id text,
  restaurants_text_id text,
  restaurant_uuid uuid,
  restaurant_name text,
  link_status text
);

DROP TABLE IF EXISTS pg_temp.phase1_bd_link_verify;
CREATE TEMP TABLE pg_temp.phase1_bd_link_verify (
  total_business_days bigint,
  missing_restaurant_id bigint,
  missing_slug bigint,
  linked_business_days bigint,
  column_mode text
);

-- =============================================================================
-- 3) UPDATE + تقرير + تحقق — فرعان منفصلان (بدون text = uuid)
-- =============================================================================
DO $$
DECLARE
  v_udt text;
  v_updated integer;
BEGIN
  SELECT c.udt_name
  INTO v_udt
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name = 'business_days'
    AND c.column_name = 'restaurant_id';

  IF v_udt IS NULL THEN
    RAISE EXCEPTION
      'phase1 business_days link: column business_days.restaurant_id not found';
  END IF;

  IF v_udt = 'uuid' THEN
    -- ── UUID: restaurant_uuid فقط ──────────────────────────────────────────
    UPDATE public.business_days bd
    SET restaurant_id = r.restaurant_uuid
    FROM public.restaurants r
    WHERE bd.slug IS NOT NULL
      AND btrim(bd.slug) <> ''
      AND lower(btrim(bd.slug)) = lower(btrim(r.slug))
      AND r.restaurant_uuid IS NOT NULL
      AND bd.restaurant_id IS DISTINCT FROM r.restaurant_uuid;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RAISE NOTICE 'phase1 business_days (uuid mode): updated % row(s)', v_updated;

    INSERT INTO pg_temp.phase1_bd_link_report
    SELECT
      bd.id,
      bd.slug,
      bd.restaurant_id::text,
      r.id,
      r.restaurant_uuid,
      r.name,
      CASE
        WHEN r.id IS NULL THEN 'NO SLUG MATCH'
        WHEN bd.restaurant_id = r.restaurant_uuid THEN 'OK — linked via restaurant_uuid'
        ELSE 'NEEDS UPDATE — slug match but uuid differs'
      END
    FROM public.business_days bd
    LEFT JOIN public.restaurants r
      ON lower(btrim(bd.slug)) = lower(btrim(r.slug))
    ORDER BY bd.opened_at DESC NULLS LAST;

    INSERT INTO pg_temp.phase1_bd_link_verify
    SELECT
      count(*),
      count(*) FILTER (WHERE bd.restaurant_id IS NULL),
      count(*) FILTER (WHERE bd.slug IS NULL OR btrim(bd.slug) = ''),
      count(*) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.restaurants r
          WHERE lower(btrim(bd.slug)) = lower(btrim(r.slug))
            AND bd.restaurant_id = r.restaurant_uuid
        )
      ),
      'uuid'
    FROM public.business_days bd;

  ELSE
    -- ── TEXT: restaurants.id فقط — لا UUID ───────────────────────────────
    UPDATE public.business_days bd
    SET restaurant_id = r.id
    FROM public.restaurants r
    WHERE bd.slug IS NOT NULL
      AND btrim(bd.slug) <> ''
      AND lower(btrim(bd.slug)) = lower(btrim(r.slug))
      AND r.id IS NOT NULL
      AND btrim(r.id) <> ''
      AND lower(btrim(bd.restaurant_id)) IS DISTINCT FROM lower(btrim(r.id));

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RAISE NOTICE 'phase1 business_days (text mode): updated % row(s)', v_updated;

    INSERT INTO pg_temp.phase1_bd_link_report
    SELECT
      bd.id,
      bd.slug,
      bd.restaurant_id::text,
      r.id,
      r.restaurant_uuid,
      r.name,
      CASE
        WHEN r.id IS NULL THEN 'NO SLUG MATCH'
        WHEN lower(btrim(bd.restaurant_id)) = lower(btrim(r.id))
          THEN 'OK — linked via restaurants.id'
        ELSE 'NEEDS UPDATE — slug match but id differs'
      END
    FROM public.business_days bd
    LEFT JOIN public.restaurants r
      ON lower(btrim(bd.slug)) = lower(btrim(r.slug))
    ORDER BY bd.opened_at DESC NULLS LAST;

    INSERT INTO pg_temp.phase1_bd_link_verify
    SELECT
      count(*),
      count(*) FILTER (
        WHERE bd.restaurant_id IS NULL OR btrim(bd.restaurant_id) = ''
      ),
      count(*) FILTER (WHERE bd.slug IS NULL OR btrim(bd.slug) = ''),
      count(*) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.restaurants r
          WHERE lower(btrim(bd.slug)) = lower(btrim(r.slug))
            AND lower(btrim(bd.restaurant_id)) = lower(btrim(r.id))
        )
      ),
      'text'
    FROM public.business_days bd;

  END IF;
END $$;

-- =============================================================================
-- 4) عرض التقرير والتحقق
-- =============================================================================
SELECT * FROM pg_temp.phase1_bd_link_report;

SELECT * FROM pg_temp.phase1_bd_link_verify;

-- =============================================================================
-- 5) فهرس
-- =============================================================================
CREATE INDEX IF NOT EXISTS business_days_restaurant_id_idx
  ON public.business_days (restaurant_id);

-- =============================================================================
-- 6) عينة — آخر 10 أيام عمل
-- =============================================================================
SELECT
  id,
  slug,
  restaurant_id,
  status,
  opened_at,
  closed_at
FROM public.business_days
ORDER BY opened_at DESC NULLS LAST, id DESC
LIMIT 10;

-- =============================================================================
-- ROLLBACK آمن (لا يحذف أيام العمل)
-- =============================================================================
-- DO $$
-- DECLARE v_udt text;
-- BEGIN
--   SELECT c.udt_name INTO v_udt
--   FROM information_schema.columns c
--   WHERE c.table_schema = 'public'
--     AND c.table_name = 'business_days'
--     AND c.column_name = 'restaurant_id';
--
--   IF v_udt = 'uuid' THEN
--     UPDATE public.business_days bd
--     SET restaurant_id = b.restaurant_id_backup::uuid
--     FROM public.business_days_restaurant_id_backfill_backup b
--     WHERE bd.id = b.business_day_id
--       AND b.restaurant_id_backup IS NOT NULL;
--   ELSE
--     UPDATE public.business_days bd
--     SET restaurant_id = b.restaurant_id_backup
--     FROM public.business_days_restaurant_id_backfill_backup b
--     WHERE bd.id = b.business_day_id
--       AND b.restaurant_id_backup IS NOT NULL;
--   END IF;
-- END $$;
--
-- DROP INDEX IF EXISTS public.business_days_restaurant_id_idx;

NOTIFY pgrst, 'reload schema';
