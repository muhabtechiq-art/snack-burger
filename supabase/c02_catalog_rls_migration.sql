-- =============================================================================
-- C-02 — Catalog RLS (تدريجي — تشخيص + backup + policies مقترحة)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- النطاق: public.products · product_addons · product_variants · banners
-- لا يعدّل: Flutter · RPC save_product_with_addons (سلوكها يبقى كما هو)
-- لا يحذف policies قديمة افتراضياً (v_enable_strict_mode = false)
--
-- ─────────────────────────────────────────────────────────────────────────────
-- ماذا سيحدث عند التنفيذ؟
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) تقرير RLS + policies الحالية للجداول الأربعة.
-- 2) backup policies → catalog_rls_policies_c02_backup.
-- 3) تقرير بيانات: restaurant_id distribution · orphan addons/variants.
-- 4) دالة catalog_matches_admin_profile(p_restaurant_id text).
-- 5) policies جديدة catalog_c02_* (لا تحذف القديمة افتراضياً).
-- 6) v_enable_strict_mode = false — لا strict mode · لا حذف policies قديمة.
-- 7) لا يُفعَّل RLS على جدول كان RLS معطّلاً عليه.
-- 8) اختبارات SQL تشخيصية في النهاية.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- خطر كسر النظام
-- ─────────────────────────────────────────────────────────────────────────────
-- • v_enable_strict_mode = false (الافتراضي): policies القديمة USING (true)
--   تبقى فعّالة — السلوك الحالي للتطبيق لا يتغيّر (OR permissive).
-- • v_enable_strict_mode = true: يحذف policies *_public_read / *_anon_* القديمة
--   — نفّذ فقط بعد اختبار authenticated admin + منيو الزبون.
-- • authenticated catalog_c02_* جاهزة للتفعيل عند strict mode.
-- • anon SELECT interim (catalog_c02_select_anon_interim) = USING (true) مؤقتاً.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- Rollback — انظر قسم ROLLBACK في آخر الملف
-- =============================================================================

-- =============================================================================
-- 1) تقرير حالة RLS — الجداول الأربعة
-- =============================================================================
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'products',
    'product_addons',
    'product_variants',
    'banners'
  )
  AND c.relkind = 'r'
ORDER BY c.relname;

-- =============================================================================
-- 2) policies الحالية — لا حذف
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
  AND tablename IN (
    'products',
    'product_addons',
    'product_variants',
    'banners'
  )
ORDER BY tablename, policyname, cmd;

-- =============================================================================
-- 3) Backup policies الحالية
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.catalog_rls_policies_c02_backup (
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

INSERT INTO public.catalog_rls_policies_c02_backup (
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
  'C-02 pre-migration snapshot'
FROM pg_policies p
JOIN pg_class c ON c.relname = p.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = p.schemaname
WHERE p.schemaname = 'public'
  AND p.tablename IN (
    'products',
    'product_addons',
    'product_variants',
    'banners'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.catalog_rls_policies_c02_backup b
    WHERE b.tablename = p.tablename
      AND b.policyname = p.policyname
      AND b.cmd IS NOT DISTINCT FROM p.cmd
      AND b.captured_at > now() - interval '1 minute'
  );

-- سجّل جداول بلا policies
INSERT INTO public.catalog_rls_policies_c02_backup (
  schemaname,
  tablename,
  policyname,
  rls_enabled_at_capture,
  notes
)
SELECT
  'public',
  t.table_name,
  '(no policies at capture)',
  c.relrowsecurity,
  'C-02: zero RLS policies at snapshot time'
FROM (
  VALUES
    ('products'),
    ('product_addons'),
    ('product_variants'),
    ('banners')
) AS t(table_name)
JOIN pg_class c ON c.relname = t.table_name
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_policies p
  WHERE p.schemaname = 'public'
    AND p.tablename = t.table_name
)
AND NOT EXISTS (
  SELECT 1
  FROM public.catalog_rls_policies_c02_backup b
  WHERE b.tablename = t.table_name
    AND b.policyname = '(no policies at capture)'
    AND b.captured_at > now() - interval '1 minute'
);

SELECT
  tablename,
  count(*) AS backup_rows,
  max(captured_at) AS last_capture
FROM public.catalog_rls_policies_c02_backup
WHERE notes = 'C-02 pre-migration snapshot'
   OR policyname = '(no policies at capture)'
GROUP BY tablename
ORDER BY tablename;

-- =============================================================================
-- 4) تقرير بيانات — products / banners حسب restaurant_id
-- =============================================================================
SELECT
  'products' AS source_table,
  coalesce(nullif(btrim(restaurant_id), ''), '(blank/null)') AS restaurant_id,
  count(*) AS row_count
FROM public.products
GROUP BY 1, 2
ORDER BY row_count DESC, restaurant_id;

SELECT
  'banners' AS source_table,
  coalesce(nullif(btrim(restaurant_id), ''), '(blank/null)') AS restaurant_id,
  count(*) AS row_count
FROM public.banners
GROUP BY 1, 2
ORDER BY row_count DESC, restaurant_id;

SELECT
  count(*) AS products_missing_restaurant_id
FROM public.products
WHERE restaurant_id IS NULL OR btrim(restaurant_id) = '';

SELECT
  count(*) AS banners_missing_restaurant_id
FROM public.banners
WHERE restaurant_id IS NULL OR btrim(restaurant_id) = '';

-- =============================================================================
-- 5) orphan addons / variants (بدون منتج أب)
-- =============================================================================
SELECT
  count(*) AS orphan_addon_rows
FROM public.product_addons a
WHERE NOT EXISTS (
  SELECT 1 FROM public.products p WHERE p.id = a.product_id
);

SELECT
  count(*) AS orphan_variant_rows
FROM public.product_variants v
WHERE NOT EXISTS (
  SELECT 1 FROM public.products p WHERE p.id = v.product_id
);

SELECT
  a.id,
  a.product_id,
  a.name
FROM public.product_addons a
WHERE NOT EXISTS (
  SELECT 1 FROM public.products p WHERE p.id = a.product_id
)
ORDER BY a.id
LIMIT 10;

SELECT
  v.id,
  v.product_id,
  v.name
FROM public.product_variants v
WHERE NOT EXISTS (
  SELECT 1 FROM public.products p WHERE p.id = v.product_id
)
ORDER BY v.id
LIMIT 10;

-- addons/variants مرتبطة بمنتج لكن restaurant_id غير معروف
SELECT
  count(*) AS addons_on_blank_restaurant_products
FROM public.product_addons a
INNER JOIN public.products p ON p.id = a.product_id
WHERE p.restaurant_id IS NULL OR btrim(p.restaurant_id) = '';

SELECT
  count(*) AS variants_on_blank_restaurant_products
FROM public.product_variants v
INNER JOIN public.products p ON p.id = v.product_id
WHERE p.restaurant_id IS NULL OR btrim(p.restaurant_id) = '';

-- =============================================================================
-- 6) دالة مساعدة — admin مصادق ↔ tenant catalog (text restaurant_id / slug)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.catalog_matches_admin_profile(
  p_restaurant_id text
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
      AND p_restaurant_id IS NOT NULL
      AND btrim(p_restaurant_id) <> ''
      AND (
        lower(btrim(p_restaurant_id)) = lower(btrim(r.id))
        OR lower(btrim(p_restaurant_id)) = lower(btrim(r.slug))
      )
  );
$$;

COMMENT ON FUNCTION public.catalog_matches_admin_profile(text) IS
  'C-02: يتحقق أن admin المصادق (profiles) يطابق tenant الكatalog عبر restaurants.id أو slug';

REVOKE ALL ON FUNCTION public.catalog_matches_admin_profile(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.catalog_matches_admin_profile(text)
  TO anon, authenticated;

-- =============================================================================
-- 7) دالة مساعدة — product_addons / product_variants عبر products.restaurant_id
-- =============================================================================
CREATE OR REPLACE FUNCTION public.catalog_product_id_matches_admin_profile(
  p_product_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.products p
    WHERE p.id = p_product_id
      AND public.catalog_matches_admin_profile(p.restaurant_id)
  );
$$;

COMMENT ON FUNCTION public.catalog_product_id_matches_admin_profile(bigint) IS
  'C-02: addons/variants — tenant match عبر products.restaurant_id';

REVOKE ALL ON FUNCTION public.catalog_product_id_matches_admin_profile(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.catalog_product_id_matches_admin_profile(bigint)
  TO anon, authenticated;

-- =============================================================================
-- 8) Policies مقترحة — catalog_c02_* (لا تحذف policies قديمة افتراضياً)
-- =============================================================================

-- ── products ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.products;
CREATE POLICY catalog_c02_select_anon_interim
  ON public.products
  FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS catalog_c02_select_authenticated_tenant ON public.products;
CREATE POLICY catalog_c02_select_authenticated_tenant
  ON public.products
  FOR SELECT
  TO authenticated
  USING (public.catalog_matches_admin_profile(restaurant_id));

DROP POLICY IF EXISTS catalog_c02_insert_authenticated_tenant ON public.products;
CREATE POLICY catalog_c02_insert_authenticated_tenant
  ON public.products
  FOR INSERT
  TO authenticated
  WITH CHECK (public.catalog_matches_admin_profile(restaurant_id));

DROP POLICY IF EXISTS catalog_c02_update_authenticated_tenant ON public.products;
CREATE POLICY catalog_c02_update_authenticated_tenant
  ON public.products
  FOR UPDATE
  TO authenticated
  USING (public.catalog_matches_admin_profile(restaurant_id))
  WITH CHECK (public.catalog_matches_admin_profile(restaurant_id));

DROP POLICY IF EXISTS catalog_c02_delete_authenticated_tenant ON public.products;
CREATE POLICY catalog_c02_delete_authenticated_tenant
  ON public.products
  FOR DELETE
  TO authenticated
  USING (public.catalog_matches_admin_profile(restaurant_id));

-- ── banners ─────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.banners;
CREATE POLICY catalog_c02_select_anon_interim
  ON public.banners
  FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS catalog_c02_select_authenticated_tenant ON public.banners;
CREATE POLICY catalog_c02_select_authenticated_tenant
  ON public.banners
  FOR SELECT
  TO authenticated
  USING (public.catalog_matches_admin_profile(restaurant_id));

DROP POLICY IF EXISTS catalog_c02_insert_authenticated_tenant ON public.banners;
CREATE POLICY catalog_c02_insert_authenticated_tenant
  ON public.banners
  FOR INSERT
  TO authenticated
  WITH CHECK (public.catalog_matches_admin_profile(restaurant_id));

DROP POLICY IF EXISTS catalog_c02_update_authenticated_tenant ON public.banners;
CREATE POLICY catalog_c02_update_authenticated_tenant
  ON public.banners
  FOR UPDATE
  TO authenticated
  USING (public.catalog_matches_admin_profile(restaurant_id))
  WITH CHECK (public.catalog_matches_admin_profile(restaurant_id));

DROP POLICY IF EXISTS catalog_c02_delete_authenticated_tenant ON public.banners;
CREATE POLICY catalog_c02_delete_authenticated_tenant
  ON public.banners
  FOR DELETE
  TO authenticated
  USING (public.catalog_matches_admin_profile(restaurant_id));

-- ── product_addons (EXISTS → products.restaurant_id) ────────────────────────

DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.product_addons;
CREATE POLICY catalog_c02_select_anon_interim
  ON public.product_addons
  FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS catalog_c02_select_authenticated_tenant ON public.product_addons;
CREATE POLICY catalog_c02_select_authenticated_tenant
  ON public.product_addons
  FOR SELECT
  TO authenticated
  USING (public.catalog_product_id_matches_admin_profile(product_id));

DROP POLICY IF EXISTS catalog_c02_insert_authenticated_tenant ON public.product_addons;
CREATE POLICY catalog_c02_insert_authenticated_tenant
  ON public.product_addons
  FOR INSERT
  TO authenticated
  WITH CHECK (public.catalog_product_id_matches_admin_profile(product_id));

DROP POLICY IF EXISTS catalog_c02_update_authenticated_tenant ON public.product_addons;
CREATE POLICY catalog_c02_update_authenticated_tenant
  ON public.product_addons
  FOR UPDATE
  TO authenticated
  USING (public.catalog_product_id_matches_admin_profile(product_id))
  WITH CHECK (public.catalog_product_id_matches_admin_profile(product_id));

DROP POLICY IF EXISTS catalog_c02_delete_authenticated_tenant ON public.product_addons;
CREATE POLICY catalog_c02_delete_authenticated_tenant
  ON public.product_addons
  FOR DELETE
  TO authenticated
  USING (public.catalog_product_id_matches_admin_profile(product_id));

-- ── product_variants (EXISTS → products.restaurant_id) ──────────────────────

DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.product_variants;
CREATE POLICY catalog_c02_select_anon_interim
  ON public.product_variants
  FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS catalog_c02_select_authenticated_tenant ON public.product_variants;
CREATE POLICY catalog_c02_select_authenticated_tenant
  ON public.product_variants
  FOR SELECT
  TO authenticated
  USING (public.catalog_product_id_matches_admin_profile(product_id));

DROP POLICY IF EXISTS catalog_c02_insert_authenticated_tenant ON public.product_variants;
CREATE POLICY catalog_c02_insert_authenticated_tenant
  ON public.product_variants
  FOR INSERT
  TO authenticated
  WITH CHECK (public.catalog_product_id_matches_admin_profile(product_id));

DROP POLICY IF EXISTS catalog_c02_update_authenticated_tenant ON public.product_variants;
CREATE POLICY catalog_c02_update_authenticated_tenant
  ON public.product_variants
  FOR UPDATE
  TO authenticated
  USING (public.catalog_product_id_matches_admin_profile(product_id))
  WITH CHECK (public.catalog_product_id_matches_admin_profile(product_id));

DROP POLICY IF EXISTS catalog_c02_delete_authenticated_tenant ON public.product_variants;
CREATE POLICY catalog_c02_delete_authenticated_tenant
  ON public.product_variants
  FOR DELETE
  TO authenticated
  USING (public.catalog_product_id_matches_admin_profile(product_id));

-- =============================================================================
-- 9) Strict mode — معطّل افتراضياً (لا حذف policies قديمة · لا ENABLE إجباري)
-- =============================================================================
DO $$
DECLARE
  v_enable_strict_mode boolean := false;  -- ⚠️ true فقط بعد اختبار التطبيق + SQL tests
  v_table text;
  v_rls_enabled boolean;
  v_dropped integer := 0;
BEGIN
  IF v_enable_strict_mode THEN
    RAISE NOTICE 'C-02: STRICT MODE — dropping legacy catalog policies USING (true)...';

    FOR v_table IN
      SELECT unnest(ARRAY[
        'products',
        'product_addons',
        'product_variants',
        'banners'
      ])
    LOOP
      EXECUTE format(
        'DROP POLICY IF EXISTS %I ON public.%I',
        v_table || '_public_read',
        v_table
      );
      EXECUTE format(
        'DROP POLICY IF EXISTS %I ON public.%I',
        v_table || '_anon_insert',
        v_table
      );
      EXECUTE format(
        'DROP POLICY IF EXISTS %I ON public.%I',
        v_table || '_anon_update',
        v_table
      );
      EXECUTE format(
        'DROP POLICY IF EXISTS %I ON public.%I',
        v_table || '_anon_delete',
        v_table
      );
      v_dropped := v_dropped + 4;
    END LOOP;

    -- banners_rls_fix.sql قد أضاف banners_authenticated_update — احذفه إن وُجد
    DROP POLICY IF EXISTS banners_authenticated_update ON public.banners;

    RAISE NOTICE 'C-02: attempted legacy policy drops (% policies × 4 tables + banners_authenticated_update)', v_dropped / 4;
  ELSE
    RAISE NOTICE
      'C-02: v_enable_strict_mode=false — legacy policies KEPT; catalog_c02_* added alongside (permissive OR).';
  END IF;

  -- لا تُفعّل RLS على جدول كان معطّلاً — فقط أبلغ بالحالة
  FOREACH v_table IN ARRAY ARRAY[
    'products',
    'product_addons',
    'product_variants',
    'banners'
  ]
  LOOP
    SELECT c.relrowsecurity
    INTO v_rls_enabled
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = v_table;

    IF coalesce(v_rls_enabled, false) THEN
      RAISE NOTICE 'C-02: % — RLS already enabled (unchanged)', v_table;
    ELSE
      RAISE NOTICE
        'C-02: % — RLS is DISABLED; NOT enabling automatically (catalog_c02_* inactive until ENABLE ROW LEVEL SECURITY)',
        v_table;
    END IF;
  END LOOP;
END $$;

-- =============================================================================
-- 10) تقرير policies بعد الإنشاء (catalog_c02 + pre-existing)
-- =============================================================================
SELECT
  tablename,
  policyname,
  roles,
  cmd,
  CASE
    WHEN policyname LIKE 'catalog_c02_%' THEN 'C-02 proposed'
    ELSE 'pre-existing'
  END AS origin
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'products',
    'product_addons',
    'product_variants',
    'banners'
  )
ORDER BY tablename, origin, policyname, cmd;

-- =============================================================================
-- 11) TESTS — نفّذ بعد Migration (SQL Editor)
-- =============================================================================

-- Test 1 — هل الدالة catalog_matches_admin_profile موجودة؟
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'catalog_matches_admin_profile',
    'catalog_product_id_matches_admin_profile'
  )
ORDER BY p.proname;

-- Test 2 — عدد catalog_c02_* policies لكل جدول (المتوقع: 5 لكل جدول)
SELECT
  tablename,
  count(*) FILTER (WHERE policyname LIKE 'catalog_c02_%') AS catalog_c02_policy_count,
  count(*) FILTER (WHERE policyname NOT LIKE 'catalog_c02_%') AS legacy_policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'products',
    'product_addons',
    'product_variants',
    'banners'
  )
GROUP BY tablename
ORDER BY tablename;

-- Test 3 — superuser read sample (يعمل دائماً في SQL Editor)
SELECT 'products' AS tbl, id, name, restaurant_id
FROM public.products
ORDER BY created_at DESC NULLS LAST
LIMIT 3;

SELECT 'banners' AS tbl, id, title, restaurant_id, is_active
FROM public.banners
ORDER BY created_at DESC NULLS LAST
LIMIT 3;

-- Test 4 — محاكاة anon SELECT (اختياري — بعد strict mode أو مع RLS enabled)
-- SET LOCAL ROLE anon;
-- SELECT count(*) AS anon_products FROM public.products;
-- SELECT count(*) AS anon_banners FROM public.banners;
-- RESET ROLE;

-- Test 5 — cross-tenant visibility check (superuser diagnostic)
-- منتجات لكل restaurant_id — للمقارنة قبل/بعد strict mode
SELECT
  p.restaurant_id,
  count(DISTINCT p.id) AS products,
  count(DISTINCT a.id) AS addons,
  count(DISTINCT v.id) AS variants
FROM public.products p
LEFT JOIN public.product_addons a ON a.product_id = p.id
LEFT JOIN public.product_variants v ON v.product_id = p.id
GROUP BY p.restaurant_id
ORDER BY products DESC;

-- Test 6 — orphan يجب = 0 قبل strict mode
SELECT
  (SELECT count(*) FROM public.product_addons a
   WHERE NOT EXISTS (SELECT 1 FROM public.products p WHERE p.id = a.product_id)
  ) AS orphan_addons,
  (SELECT count(*) FROM public.product_variants v
   WHERE NOT EXISTS (SELECT 1 FROM public.products p WHERE p.id = v.product_id)
  ) AS orphan_variants;

-- Test 7 — من التطبيق (يدوي):
--   • منيو زبون tenant A — منتجات + بanners
--   • admin tenant A — CRUD منتج/بانر
--   • admin tenant A — لا يرى/يعدّل catalog tenant B (بعد v_enable_strict_mode=true)
--   • save_product_with_addons — حفظ منتج + addons

-- =============================================================================
-- ROLLBACK — نفّذ يدوياً عند الحاجة
-- =============================================================================
-- -- (أ) إزالة policies C-02 فقط — يعيد الاعتماد على policies القديمة
-- DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.products;
-- DROP POLICY IF EXISTS catalog_c02_select_authenticated_tenant ON public.products;
-- DROP POLICY IF EXISTS catalog_c02_insert_authenticated_tenant ON public.products;
-- DROP POLICY IF EXISTS catalog_c02_update_authenticated_tenant ON public.products;
-- DROP POLICY IF EXISTS catalog_c02_delete_authenticated_tenant ON public.products;
--
-- DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.banners;
-- DROP POLICY IF EXISTS catalog_c02_select_authenticated_tenant ON public.banners;
-- DROP POLICY IF EXISTS catalog_c02_insert_authenticated_tenant ON public.banners;
-- DROP POLICY IF EXISTS catalog_c02_update_authenticated_tenant ON public.banners;
-- DROP POLICY IF EXISTS catalog_c02_delete_authenticated_tenant ON public.banners;
--
-- DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.product_addons;
-- DROP POLICY IF EXISTS catalog_c02_select_authenticated_tenant ON public.product_addons;
-- DROP POLICY IF EXISTS catalog_c02_insert_authenticated_tenant ON public.product_addons;
-- DROP POLICY IF EXISTS catalog_c02_update_authenticated_tenant ON public.product_addons;
-- DROP POLICY IF EXISTS catalog_c02_delete_authenticated_tenant ON public.product_addons;
--
-- DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.product_variants;
-- DROP POLICY IF EXISTS catalog_c02_select_authenticated_tenant ON public.product_variants;
-- DROP POLICY IF EXISTS catalog_c02_insert_authenticated_tenant ON public.product_variants;
-- DROP POLICY IF EXISTS catalog_c02_update_authenticated_tenant ON public.product_variants;
-- DROP POLICY IF EXISTS catalog_c02_delete_authenticated_tenant ON public.product_variants;
--
-- DROP FUNCTION IF EXISTS public.catalog_product_id_matches_admin_profile(bigint);
-- DROP FUNCTION IF EXISTS public.catalog_matches_admin_profile(text);
--
-- -- (ب) تعطيل RLS بالكامل (طوارئ — يعيد ثغرة cross-tenant)
-- -- ALTER TABLE public.products DISABLE ROW LEVEL SECURITY;
-- -- ALTER TABLE public.product_addons DISABLE ROW LEVEL SECURITY;
-- -- ALTER TABLE public.product_variants DISABLE ROW LEVEL SECURITY;
-- -- ALTER TABLE public.banners DISABLE ROW LEVEL SECURITY;
--
-- -- (ج) جدول catalog_rls_policies_c02_backup يُترك للمرجع — لا يحذف بيانات catalog

NOTIFY pgrst, 'reload schema';
