-- =============================================================================
-- C-01 — Orders RLS (تدريجي — تشخيص + backup + policies مقترحة)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- النطاق: جدول public.orders فقط
-- لا يعدّل: Flutter · RPC submit_customer_order · products · banners · business_days
-- لا يغيّر بيانات orders (SELECT/INSERT backup policies فقط)
--
-- ─────────────────────────────────────────────────────────────────────────────
-- ماذا سيحدث عند التنفيذ؟
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) تقرير: هل RLS مفعّل على orders؟ + قائمة policies الحالية (بدون حذف).
-- 2) نسخة احتياطية لـ policies الحالية في جدول orders_rls_policies_c01_backup.
-- 3) فحص جاهزية البيانات (restaurant_id UUID + slug).
-- 4) دالة مساعدة orders_matches_admin_profile للربط admin ↔ tenant.
-- 5) إنشاء policies مقترحة بأسماء orders_c01_* (لا تُحذف policies قديمة).
-- 6) تفعيل RLS معطّل افتراضياً (v_enable_rls = false) — لا كسر للتطبيق.
-- 7) اختباران تشخيصيان في النهاية.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- خطر كسر النظام
-- ─────────────────────────────────────────────────────────────────────────────
-- • v_enable_rls = false (الافتراضي): لا تغيير سلوك — آمن 100%.
-- • v_enable_rls = true بدون policies كافية: يمنع كل SELECT/UPDATE من anon/auth.
-- • v_enable_rls = true + policies_c01:
--     - INSERT مباشر من العميل: مرفوض (submit_customer_order = SECURITY DEFINER ✓).
--     - SELECT anon interim (USING true): يحافظ على سلوك التطبيق الحالي مؤقتاً.
--     - SELECT/UPDATE authenticated: مقيد بـ profiles.restaurant_id ↔ slug/uuid.
--     - طلبات قديمة بدون restaurant_id: قد لا يراها admin بعد التفعيل الصارم.
-- • Realtime full-table streams: anon interim يسمح بالكل حتى C-03.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- الرجوع للخلف (Rollback)
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
-- 2) حذف policies C-01 فقط (انظر قسم ROLLBACK في آخر الملف).
-- 3) DROP FUNCTION public.orders_matches_admin_profile;
-- 4) جدول orders_rls_policies_c01_backup يبقى للمرجع — لا يحذف بيانات orders.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- الاختبار بعد التنفيذ
-- ─────────────────────────────────────────────────────────────────────────────
-- • راجع تقرير RLS + policies الحالية + backup row count.
-- • راجع data_readiness (missing_restaurant_id يجب ≈ 0 بعد Phase 1).
-- • نفّذ قسم الاختبارين (5) في SQL Editor.
-- • بعد تفعيل RLS (v_enable_rls = true): اختبر من التطبيق:
--     - إرسال طلب زبون (RPC)
--     - متابعة طلب / طلباتي (anon SELECT)
--     - قبول/رفض طلب (authenticated UPDATE)
-- =============================================================================

-- =============================================================================
-- 1) تقرير حالة RLS على orders
-- =============================================================================
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'orders'
  AND c.relkind = 'r';

-- =============================================================================
-- 2) عرض policies الحالية — لا حذف
-- =============================================================================
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'orders'
ORDER BY policyname, cmd;

-- =============================================================================
-- 3) Backup / diagnostic report للـ policies الحالية
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.orders_rls_policies_c01_backup (
  backup_id bigserial PRIMARY KEY,
  captured_at timestamptz NOT NULL DEFAULT now(),
  schemaname text NOT NULL,
  tablename text NOT NULL,
  policyname text NOT NULL,
  permissive text,
  roles text[],
  cmd text,
  using_expression text,
  with_check_expression text,
  rls_enabled_at_capture boolean NOT NULL,
  notes text
);

INSERT INTO public.orders_rls_policies_c01_backup (
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  using_expression,
  with_check_expression,
  rls_enabled_at_capture,
  notes
)
SELECT
  p.schemaname,
  p.tablename,
  p.policyname,
  p.permissive,
  p.roles,
  p.cmd,
  p.qual,
  p.with_check,
  c.relrowsecurity,
  'C-01 pre-migration snapshot'
FROM pg_policies p
JOIN pg_class c ON c.relname = p.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = p.schemaname
WHERE p.schemaname = 'public'
  AND p.tablename = 'orders'
  AND NOT EXISTS (
    SELECT 1
    FROM public.orders_rls_policies_c01_backup b
    WHERE b.policyname = p.policyname
      AND b.cmd = p.cmd
      AND b.captured_at > now() - interval '1 minute'
  );

-- إذا لم توجد policies — سجّل ذلك
INSERT INTO public.orders_rls_policies_c01_backup (
  schemaname,
  tablename,
  policyname,
  rls_enabled_at_capture,
  notes
)
SELECT
  'public',
  'orders',
  '(no policies at capture)',
  c.relrowsecurity,
  'C-01: orders had zero RLS policies at snapshot time'
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'orders'
  AND NOT EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = 'public' AND p.tablename = 'orders'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.orders_rls_policies_c01_backup b
    WHERE b.policyname = '(no policies at capture)'
      AND b.captured_at > now() - interval '1 minute'
  );

SELECT
  count(*) AS backup_rows,
  max(captured_at) AS last_capture
FROM public.orders_rls_policies_c01_backup;

-- =============================================================================
-- 4) فحص جاهزية البيانات — restaurant_id + slug
-- =============================================================================
SELECT
  count(*) AS total_orders,
  count(*) FILTER (WHERE restaurant_id IS NULL) AS missing_restaurant_id,
  count(*) FILTER (WHERE slug IS NULL OR btrim(slug) = '') AS missing_slug,
  count(*) FILTER (
    WHERE restaurant_id IS NOT NULL
      AND slug IS NOT NULL
      AND btrim(slug) <> ''
      AND EXISTS (
        SELECT 1
        FROM public.restaurants r
        WHERE lower(btrim(r.slug)) = lower(btrim(o.slug))
          AND r.restaurant_uuid IS NOT NULL
          AND o.restaurant_id::text = r.restaurant_uuid::text
      )
  ) AS linked_uuid_and_slug
FROM public.orders o;

-- =============================================================================
-- 5) دالة مساعدة — هل المستخدم المصادق (admin) يملك tenant الطلب؟
--    تربط profiles.restaurant_id (text) ↔ restaurants.id/slug ↔ orders
-- =============================================================================
CREATE OR REPLACE FUNCTION public.orders_matches_admin_profile(
  p_order_restaurant_id text,
  p_order_slug text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    INNER JOIN public.restaurants r ON (
      lower(btrim(coalesce(p.restaurant_id, ''))) = lower(btrim(r.id))
      OR lower(btrim(coalesce(p.restaurant_id, ''))) = lower(btrim(r.slug))
    )
    WHERE p.id = auth.uid()
      AND (
        (
          p_order_restaurant_id IS NOT NULL
          AND btrim(p_order_restaurant_id) <> ''
          AND r.restaurant_uuid IS NOT NULL
          AND p_order_restaurant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          AND p_order_restaurant_id::uuid = r.restaurant_uuid
        )
        OR (
          p_order_slug IS NOT NULL
          AND btrim(p_order_slug) <> ''
          AND lower(btrim(p_order_slug)) = lower(btrim(r.slug))
        )
      )
  );
$$;

COMMENT ON FUNCTION public.orders_matches_admin_profile(text, text) IS
  'C-01: يتحقق أن admin المصادق (profiles) يطابق tenant الطلب عبر slug أو restaurant_uuid';

REVOKE ALL ON FUNCTION public.orders_matches_admin_profile(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.orders_matches_admin_profile(text, text)
  TO anon, authenticated;

-- =============================================================================
-- 6) Policies مقترحة — orders_c01_* (لا تحذف policies قديمة)
-- =============================================================================

-- ── SELECT: admin مصادق — tenant-scoped عبر restaurant_id أو slug ────────────
DROP POLICY IF EXISTS orders_c01_select_authenticated_tenant
  ON public.orders;

CREATE POLICY orders_c01_select_authenticated_tenant
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (
    public.orders_matches_admin_profile(
      restaurant_id::text,
      slug
    )
  );

-- ── SELECT: anon — INTERIM مؤقت (يحاكي السلوك الحالي بدون تغيير Flutter) ───
--    يُستبدل لاحقاً بـ policy tenant-scoped عند C-03 (فلترة server-side)
DROP POLICY IF EXISTS orders_c01_select_anon_interim
  ON public.orders;

CREATE POLICY orders_c01_select_anon_interim
  ON public.orders
  FOR SELECT
  TO anon
  USING (true);

-- ── INSERT: لا policy — الطلبات الجديدة عبر submit_customer_order (DEFINER) ─
--    عند تفعيل RLS: INSERT مباشر من anon/authenticated = مرفوض (آمن)
--    RPC SECURITY DEFINER يتخطى RLS — لا حاجة لـ INSERT policy

-- ── UPDATE: لوحة الكاشير/admin — authenticated + tenant match فقط ───────────
DROP POLICY IF EXISTS orders_c01_update_authenticated_admin
  ON public.orders;

CREATE POLICY orders_c01_update_authenticated_admin
  ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    public.orders_matches_admin_profile(
      restaurant_id::text,
      slug
    )
  )
  WITH CHECK (
    public.orders_matches_admin_profile(
      restaurant_id::text,
      slug
    )
  );

-- ── DELETE: غير مستخدم من التطبيق — purge_old_rejected_orders = DEFINER ─────
--    لا policy = مرفوض عند تفعيل RLS (آمن)

-- =============================================================================
-- 7) تفعيل RLS — معطّل افتراضياً (غيّر إلى true بعد مراجعة التقرير)
-- =============================================================================
DO $$
DECLARE
  v_enable_rls boolean := false;  -- ⚠️ true فقط بعد التأكد من data_readiness + اختبار
  v_already_enabled boolean;
BEGIN
  SELECT c.relrowsecurity
  INTO v_already_enabled
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'orders';

  IF v_enable_rls THEN
    ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
    RAISE NOTICE 'C-01: RLS ENABLED on public.orders';
  ELSE
    RAISE NOTICE
      'C-01: RLS NOT enabled (v_enable_rls=false). Policies created but inactive until RLS on.';
    IF v_already_enabled THEN
      RAISE NOTICE 'C-01: RLS was already enabled before this run — existing policies still apply.';
    END IF;
  END IF;
END $$;

-- =============================================================================
-- 8) تقرير policies بعد الإنشاء (C-01 + أي policies قديمة)
-- =============================================================================
SELECT
  policyname,
  roles,
  cmd,
  CASE
    WHEN policyname LIKE 'orders_c01_%' THEN 'C-01 proposed'
    ELSE 'pre-existing'
  END AS origin
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'orders'
ORDER BY origin, policyname, cmd;

-- =============================================================================
-- 9) اختبار 1 — هل آخر 5 طلبات يمكن قراءتها؟
--    (superuser في SQL Editor = دائماً نعم؛ محاكاة anon/authenticated اختيارية)
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
LIMIT 5;

-- محاكاة anon (اختياري — نفّذ فقط إذا RLS مفعّل):
-- SET LOCAL ROLE anon;
-- SELECT id, slug, status FROM public.orders ORDER BY created_at DESC LIMIT 5;
-- RESET ROLE;

-- =============================================================================
-- 10) اختبار 2 — هل آخر طلب مربوط بـ restaurant_uuid و slug صحيح؟
-- =============================================================================
WITH last_order AS (
  SELECT o.*
  FROM public.orders o
  ORDER BY o.created_at DESC NULLS LAST, o.id DESC
  LIMIT 1
)
SELECT
  lo.id AS order_id,
  lo.slug AS order_slug,
  lo.restaurant_id AS order_restaurant_id,
  r.id AS restaurant_text_id,
  r.slug AS restaurant_slug,
  r.restaurant_uuid,
  CASE
    WHEN lo.slug IS NULL OR btrim(lo.slug) = '' THEN 'FAIL — missing slug'
    WHEN lo.restaurant_id IS NULL THEN 'FAIL — missing restaurant_id'
    WHEN r.restaurant_uuid IS NULL THEN 'FAIL — restaurant has no uuid'
    WHEN lower(btrim(lo.slug)) <> lower(btrim(r.slug)) THEN 'FAIL — slug mismatch'
    WHEN lo.restaurant_id::text <> r.restaurant_uuid::text THEN 'FAIL — uuid mismatch'
    ELSE 'OK — linked'
  END AS link_status
FROM last_order lo
LEFT JOIN public.restaurants r
  ON lower(btrim(r.slug)) = lower(btrim(lo.slug));

-- =============================================================================
-- ROLLBACK — نفّذ يدوياً عند الحاجة
-- =============================================================================
-- ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;
--
-- DROP POLICY IF EXISTS orders_c01_select_authenticated_tenant ON public.orders;
-- DROP POLICY IF EXISTS orders_c01_select_anon_interim ON public.orders;
-- DROP POLICY IF EXISTS orders_c01_update_authenticated_admin ON public.orders;
--
-- DROP FUNCTION IF EXISTS public.orders_matches_admin_profile(text, text);
--
-- -- جدول orders_rls_policies_c01_backup يُترك للمرجع

NOTIFY pgrst, 'reload schema';
