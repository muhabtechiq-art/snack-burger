-- =============================================================================
-- C-03 — Storage RLS Hardening (تدريجي — تشخيص + backup + policies مقترحة)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- النطاق: storage.objects — buckets: product-images · daily-sounds
-- لا يعدّل: Flutter · إعدادات public على buckets · سياسات Legacy (حتى strict)
--
-- ─────────────────────────────────────────────────────────────────────────────
-- متطلب سابق (إلزامي)
-- ─────────────────────────────────────────────────────────────────────────────
-- يجب تنفيذ C-02 أولاً حتى تكون الدالة public.catalog_matches_admin_profile
-- موجودة (c02_catalog_rls_migration.sql §6).
-- هذا الملف لا يُنشئ نسخة بديلة منها.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- ماذا سيحدث عند التنفيذ؟
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) تقرير buckets + سياسات storage.objects الحالية.
-- 2) backup policies → storage_rls_policies_c03_backup.
-- 3) فحص وجود catalog_matches_admin_profile.
-- 4) دالة storage_object_tenant_folder(p_name text).
-- 5) policies جديدة storage_c03_* (لا تحذف القديمة افتراضياً).
-- 6) v_enable_strict_mode = false — لا حذف policies قديمة.
-- 7) اختبارات SQL تشخيصية في النهاية.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- خطر كسر النظام
-- ─────────────────────────────────────────────────────────────────────────────
-- • v_enable_strict_mode = false (الافتراضي): policies القديمة permissive
--   تبقى فعّالة — سلوك الرفع/الحذف لا يتغيّر (OR permissive).
-- • v_enable_strict_mode = true: يحذف policies *_anon_* و *_public_read القديمة
--   على هذين الـ bucketين — نفّذ فقط بعد اختبار admin uploads + منيو الزبون.
-- • بعد strict: INSERT/UPDATE/DELETE تتطلب authenticated + tenant match.
-- • SELECT العام يبقى عبر storage_c03_*_select_public (getPublicUrl).
--
-- ─────────────────────────────────────────────────────────────────────────────
-- Rollback — انظر قسم ROLLBACK في آخر الملف
-- =============================================================================

-- =============================================================================
-- 1) تقرير buckets — product-images · daily-sounds
-- =============================================================================
SELECT
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types,
  created_at,
  updated_at
FROM storage.buckets
WHERE id IN ('product-images', 'daily-sounds')
ORDER BY id;

-- =============================================================================
-- 2) policies الحالية على storage.objects — لا حذف
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
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
    policyname IN (
      'product_images_public_read',
      'product_images_anon_insert',
      'product_images_anon_update',
      'daily_sounds_public_read',
      'daily_sounds_anon_insert',
      'daily_sounds_anon_update',
      'daily_sounds_anon_delete'
    )
    OR policyname LIKE 'storage_c03_%'
  )
ORDER BY policyname, cmd;

-- =============================================================================
-- 3) Backup policies الحالية (Legacy + أي storage_c03 سابقة)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.storage_rls_policies_c03_backup (
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
  notes text
);

INSERT INTO public.storage_rls_policies_c03_backup (
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  using_expression,
  with_check_expression,
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
  'C-03 pre-migration snapshot'
FROM pg_policies p
WHERE p.schemaname = 'storage'
  AND p.tablename = 'objects'
  AND (
    p.policyname IN (
      'product_images_public_read',
      'product_images_anon_insert',
      'product_images_anon_update',
      'daily_sounds_public_read',
      'daily_sounds_anon_insert',
      'daily_sounds_anon_update',
      'daily_sounds_anon_delete'
    )
    OR p.policyname LIKE 'storage_c03_%'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.storage_rls_policies_c03_backup b
    WHERE b.policyname = p.policyname
      AND b.cmd IS NOT DISTINCT FROM p.cmd
      AND b.captured_at > now() - interval '1 minute'
  );

SELECT
  policyname,
  cmd,
  count(*) AS backup_rows,
  max(captured_at) AS last_capture
FROM public.storage_rls_policies_c03_backup
WHERE notes = 'C-03 pre-migration snapshot'
GROUP BY policyname, cmd
ORDER BY policyname, cmd;

-- =============================================================================
-- 4) فحص متطلب C-02 — catalog_matches_admin_profile
-- =============================================================================
-- ⚠️ إذا أرجع 0 صفوف: أوقف التنفيذ ونفّذ c02_catalog_rls_migration.sql §6 أولاً.
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'catalog_matches_admin_profile'
ORDER BY p.proname;

-- =============================================================================
-- 5) دالة مساعدة — tenant folder من مسار object
--    مسارات التطبيق:
--      product-images: {tenant}/{productId}/{file}
--      product-images: {tenant}/banners/{bannerId}.jpg
--      daily-sounds:   {tenant}/{timestamp}_{file}
-- =============================================================================
CREATE OR REPLACE FUNCTION public.storage_object_tenant_folder(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT NULLIF(lower(btrim((storage.foldername(p_name))[1])), '');
$$;

COMMENT ON FUNCTION public.storage_object_tenant_folder(text) IS
  'C-03: أول segment في مسار storage object = مفتاح tenant (restaurants.id أو slug)';

REVOKE ALL ON FUNCTION public.storage_object_tenant_folder(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.storage_object_tenant_folder(text)
  TO authenticated;

-- =============================================================================
-- 6) Policies مقترحة — storage_c03_* (لا تحذف policies قديمة افتراضياً)
--    تعتمد على: public.catalog_matches_admin_profile (من C-02)
-- =============================================================================

-- ── product-images ──────────────────────────────────────────────────────────

DROP POLICY IF EXISTS storage_c03_product_images_select_public ON storage.objects;
CREATE POLICY storage_c03_product_images_select_public
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS storage_c03_product_images_insert_authenticated_tenant
  ON storage.objects;
CREATE POLICY storage_c03_product_images_insert_authenticated_tenant
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'product-images'
    AND public.catalog_matches_admin_profile(
      public.storage_object_tenant_folder(name)
    )
  );

DROP POLICY IF EXISTS storage_c03_product_images_update_authenticated_tenant
  ON storage.objects;
CREATE POLICY storage_c03_product_images_update_authenticated_tenant
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.catalog_matches_admin_profile(
      public.storage_object_tenant_folder(name)
    )
  )
  WITH CHECK (
    bucket_id = 'product-images'
    AND public.catalog_matches_admin_profile(
      public.storage_object_tenant_folder(name)
    )
  );

DROP POLICY IF EXISTS storage_c03_product_images_delete_authenticated_tenant
  ON storage.objects;
CREATE POLICY storage_c03_product_images_delete_authenticated_tenant
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'product-images'
    AND public.catalog_matches_admin_profile(
      public.storage_object_tenant_folder(name)
    )
  );

-- ── daily-sounds ──────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS storage_c03_daily_sounds_select_public ON storage.objects;
CREATE POLICY storage_c03_daily_sounds_select_public
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'daily-sounds');

DROP POLICY IF EXISTS storage_c03_daily_sounds_insert_authenticated_tenant
  ON storage.objects;
CREATE POLICY storage_c03_daily_sounds_insert_authenticated_tenant
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'daily-sounds'
    AND public.catalog_matches_admin_profile(
      public.storage_object_tenant_folder(name)
    )
  );

DROP POLICY IF EXISTS storage_c03_daily_sounds_update_authenticated_tenant
  ON storage.objects;
CREATE POLICY storage_c03_daily_sounds_update_authenticated_tenant
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'daily-sounds'
    AND public.catalog_matches_admin_profile(
      public.storage_object_tenant_folder(name)
    )
  )
  WITH CHECK (
    bucket_id = 'daily-sounds'
    AND public.catalog_matches_admin_profile(
      public.storage_object_tenant_folder(name)
    )
  );

DROP POLICY IF EXISTS storage_c03_daily_sounds_delete_authenticated_tenant
  ON storage.objects;
CREATE POLICY storage_c03_daily_sounds_delete_authenticated_tenant
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'daily-sounds'
    AND public.catalog_matches_admin_profile(
      public.storage_object_tenant_folder(name)
    )
  );

-- =============================================================================
-- 7) Strict mode — معطّل افتراضياً (لا حذف policies قديمة)
-- =============================================================================
DO $$
DECLARE
  v_enable_strict_mode boolean := false;  -- ⚠️ true فقط بعد اختبار admin uploads + منيو
BEGIN
  IF v_enable_strict_mode THEN
    RAISE NOTICE 'C-03: STRICT MODE — dropping legacy storage policies on product-images + daily-sounds...';

    DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
    DROP POLICY IF EXISTS "product_images_anon_insert" ON storage.objects;
    DROP POLICY IF EXISTS "product_images_anon_update" ON storage.objects;

    DROP POLICY IF EXISTS "daily_sounds_public_read" ON storage.objects;
    DROP POLICY IF EXISTS "daily_sounds_anon_insert" ON storage.objects;
    DROP POLICY IF EXISTS "daily_sounds_anon_update" ON storage.objects;
    DROP POLICY IF EXISTS "daily_sounds_anon_delete" ON storage.objects;

    RAISE NOTICE 'C-03: legacy storage policies dropped; SELECT via storage_c03_*_select_public remains.';
  ELSE
    RAISE NOTICE
      'C-03: v_enable_strict_mode=false — legacy storage policies KEPT; '
      'storage_c03_* added alongside (permissive OR).';
  END IF;
END $$;

-- =============================================================================
-- 8) تقرير policies بعد الإنشاء (storage_c03 + pre-existing)
-- =============================================================================
SELECT
  policyname,
  roles,
  cmd,
  CASE
    WHEN policyname LIKE 'storage_c03_%' THEN 'C-03 proposed'
    ELSE 'pre-existing'
  END AS origin
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
    policyname IN (
      'product_images_public_read',
      'product_images_anon_insert',
      'product_images_anon_update',
      'daily_sounds_public_read',
      'daily_sounds_anon_insert',
      'daily_sounds_anon_update',
      'daily_sounds_anon_delete'
    )
    OR policyname LIKE 'storage_c03_%'
  )
ORDER BY origin, policyname, cmd;

-- =============================================================================
-- 9) TESTS — نفّذ بعد Migration (SQL Editor)
-- =============================================================================

-- Test 1 — هل الدوال المساعدة موجودة؟
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'catalog_matches_admin_profile',
    'storage_object_tenant_folder'
  )
ORDER BY p.proname;

-- Test 2 — عدد storage_c03_* policies (المتوقع: 8)
SELECT
  count(*) FILTER (WHERE policyname LIKE 'storage_c03_%') AS storage_c03_policy_count,
  count(*) FILTER (
    WHERE policyname IN (
      'product_images_public_read',
      'product_images_anon_insert',
      'product_images_anon_update',
      'daily_sounds_public_read',
      'daily_sounds_anon_insert',
      'daily_sounds_anon_update',
      'daily_sounds_anon_delete'
    )
  ) AS legacy_policy_count
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects';

-- Test 3 — تفصيل storage_c03_* لكل bucket
SELECT
  policyname,
  roles,
  cmd
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname LIKE 'storage_c03_%'
ORDER BY policyname, cmd;

-- Test 4 — عينة مسارات tenant folder (superuser diagnostic)
SELECT
  name,
  bucket_id,
  public.storage_object_tenant_folder(name) AS tenant_folder
FROM storage.objects
WHERE bucket_id IN ('product-images', 'daily-sounds')
ORDER BY created_at DESC NULLS LAST
LIMIT 10;

-- Test 5 — من التطبيق (يدوي):
--   • admin مسجّل: رفع صورة منتج (product-images/{tenant}/...)
--   • admin مسجّل: رفع/استبدال صورة بانر ({tenant}/banners/...)
--   • admin مسجّل: رفع/حذف صوت يومي (daily-sounds/{slug}/...)
--   • زبون: عرض صور المنيو + تشغيل صوت (getPublicUrl — بدون تغيير)
--   • بعد v_enable_strict_mode=true: رفع بدون تسجيل دخول → مرفوض

-- =============================================================================
-- ROLLBACK — نفّذ يدوياً عند الحاجة
-- =============================================================================
-- -- (أ) إزالة policies C-03 فقط — يعيد الاعتماد على policies القديمة
-- DROP POLICY IF EXISTS storage_c03_product_images_select_public ON storage.objects;
-- DROP POLICY IF EXISTS storage_c03_product_images_insert_authenticated_tenant ON storage.objects;
-- DROP POLICY IF EXISTS storage_c03_product_images_update_authenticated_tenant ON storage.objects;
-- DROP POLICY IF EXISTS storage_c03_product_images_delete_authenticated_tenant ON storage.objects;
--
-- DROP POLICY IF EXISTS storage_c03_daily_sounds_select_public ON storage.objects;
-- DROP POLICY IF EXISTS storage_c03_daily_sounds_insert_authenticated_tenant ON storage.objects;
-- DROP POLICY IF EXISTS storage_c03_daily_sounds_update_authenticated_tenant ON storage.objects;
-- DROP POLICY IF EXISTS storage_c03_daily_sounds_delete_authenticated_tenant ON storage.objects;
--
-- DROP FUNCTION IF EXISTS public.storage_object_tenant_folder(text);
--
-- -- (ب) إذا حُذفت Legacy في strict mode — أعد إنشاءها من:
-- --     supabase/storage_product_images_policies.sql
-- --     supabase/daily_sounds_storage_policies.sql
-- -- ثم NOTIFY pgrst, 'reload schema';
--
-- -- (ج) جدول storage_rls_policies_c03_backup يُترك للمرجع

NOTIFY pgrst, 'reload schema';
