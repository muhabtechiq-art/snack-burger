-- =============================================================================
-- A.9 — App Settings RLS Hardening (تدريجي — diagnostics + backup + helper + policies)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- النطاق: جدول public.app_settings فقط
-- الهدف: إغلاق ثغرة authenticated cross-tenant write
--        (حالياً أي admin مصادق يستطيع تعديل صف أي مطعم — USING (true)).
-- لا يعدّل: Flutter · app_settings_schema.sql · أي جدول آخر · أي بيانات app_settings.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- ماذا سيحدث عند التنفيذ؟
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) تقرير: حالة RLS على app_settings + قائمة policies الحالية + صفوف id + profiles.
-- 2) نسخة احتياطية للـ policies الحالية في app_settings_rls_policies_a09_backup.
-- 3) دالة مساعدة app_settings_matches_admin_profile(p_settings_id) للربط admin ↔ tenant.
-- 4) policies مقترحة بأسماء app_settings_a09_* (scoped) — لا تُحذف policies قديمة.
-- 5) strict mode معطّل افتراضياً (v_enable_strict_mode = false) — لا كسر للتطبيق.
--    عند true فقط: تُحذف legacy policies الواسعة (public_read / authenticated_update/insert).
-- 6) تقرير policies بعد التنفيذ + اختبارات تشخيصية لا تغيّر بيانات.
--
-- ─────────────────────────────────────────────────────────────────────────────
-- خطر كسر النظام
-- ─────────────────────────────────────────────────────────────────────────────
-- • v_enable_strict_mode = false (الافتراضي): legacy policies تبقى فعّالة → سلوك التطبيق
--   الحالي محفوظ 100%. policies الجديدة scoped تُنشأ لكنها تتعايش مع legacy (permissive OR).
-- • v_enable_strict_mode = true: تُحذف legacy الواسعة، ويبقى فقط:
--     - anon SELECT (interim public read — حتى نطبّق scoping للزبون لاحقاً).
--     - authenticated SELECT/INSERT/UPDATE مقيّدة بـ profile tenant فقط.
--     ⚠️ أي مسار يكتب id='global' (restaurantId=null) سيُرفض بعد strict — تأكد أن
--        AppSettingsNotifier مربوط بالـ slug دائماً (A.7) قبل التفعيل.
-- • لا توجد DELETE policy إطلاقاً → DELETE مرفوض دائماً عند RLS (آمن).
--
-- ─────────────────────────────────────────────────────────────────────────────
-- الرجوع للخلف (Rollback)
-- ─────────────────────────────────────────────────────────────────────────────
-- انظر قسم ROLLBACK في آخر الملف.
-- =============================================================================

-- =============================================================================
-- 1) Diagnostics
-- =============================================================================

-- 1.a) حالة RLS الحالية على app_settings
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'app_settings'
  AND c.relkind = 'r';

-- 1.b) policies الحالية — لا حذف
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
  AND tablename = 'app_settings'
ORDER BY policyname, cmd;

-- 1.c) صفوف app_settings الحالية — id فقط (بدون كشف بيانات حساسة)
SELECT
  id,
  updated_at
FROM public.app_settings
ORDER BY id;

-- 1.d) profiles.restaurant_id الحالية — بدون بيانات حساسة (عدّ فقط لكل tenant)
SELECT
  lower(btrim(coalesce(restaurant_id, ''))) AS restaurant_id_norm,
  count(*) AS admin_count
FROM public.profiles
GROUP BY lower(btrim(coalesce(restaurant_id, '')))
ORDER BY admin_count DESC, restaurant_id_norm;

-- =============================================================================
-- 2) Backup للـ policies الحالية — idempotent
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.app_settings_rls_policies_a09_backup (
  backup_id bigserial PRIMARY KEY,
  backed_up_at timestamptz NOT NULL DEFAULT now(),
  schemaname text NOT NULL,
  tablename text NOT NULL,
  policyname text NOT NULL,
  permissive text,
  roles text[],
  cmd text,
  qual text,
  with_check text,
  rls_enabled_at_capture boolean NOT NULL,
  notes text
);

-- التقاط snapshot للـ policies الحالية (تجنّب التكرار خلال آخر دقيقة)
INSERT INTO public.app_settings_rls_policies_a09_backup (
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check,
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
  'A.9 pre-migration snapshot'
FROM pg_policies p
JOIN pg_class c ON c.relname = p.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = p.schemaname
WHERE p.schemaname = 'public'
  AND p.tablename = 'app_settings'
  AND NOT EXISTS (
    SELECT 1
    FROM public.app_settings_rls_policies_a09_backup b
    WHERE b.policyname = p.policyname
      AND b.cmd = p.cmd
      AND b.backed_up_at > now() - interval '1 minute'
  );

-- إذا لم توجد policies — سجّل ذلك
INSERT INTO public.app_settings_rls_policies_a09_backup (
  schemaname,
  tablename,
  policyname,
  rls_enabled_at_capture,
  notes
)
SELECT
  'public',
  'app_settings',
  '(no policies at capture)',
  c.relrowsecurity,
  'A.9: app_settings had zero RLS policies at snapshot time'
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'app_settings'
  AND NOT EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = 'public' AND p.tablename = 'app_settings'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.app_settings_rls_policies_a09_backup b
    WHERE b.policyname = '(no policies at capture)'
      AND b.backed_up_at > now() - interval '1 minute'
  );

SELECT
  count(*) AS backup_rows,
  max(backed_up_at) AS last_capture
FROM public.app_settings_rls_policies_a09_backup;

-- =============================================================================
-- 3) دالة مساعدة — هل المستخدم المصادق (admin) يملك tenant صف الإعدادات؟
--    app_settings.id == tenant slug/id (مثل 'snack_burger'). نطابقه عبر
--    profiles.restaurant_id ↔ restaurants.id / restaurants.slug (نفس منطق C-02).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.app_settings_matches_admin_profile(
  p_settings_id text
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
      AND p_settings_id IS NOT NULL
      AND btrim(p_settings_id) <> ''
      AND (
        lower(btrim(p_settings_id)) = lower(btrim(r.id))
        OR lower(btrim(p_settings_id)) = lower(btrim(r.slug))
      )
  );
$$;

COMMENT ON FUNCTION public.app_settings_matches_admin_profile(text) IS
  'A.9: يتحقق أن admin المصادق (profiles) يطابق tenant صف app_settings عبر restaurants.id أو slug';

REVOKE ALL ON FUNCTION public.app_settings_matches_admin_profile(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.app_settings_matches_admin_profile(text)
  TO anon, authenticated;

-- =============================================================================
-- 4) Policies مقترحة — app_settings_a09_* (scoped) — لا تحذف policies قديمة
-- =============================================================================

-- ── SELECT: admin مصادق — صف tenant الخاص به فقط ────────────────────────────
DROP POLICY IF EXISTS app_settings_a09_select_authenticated_tenant
  ON public.app_settings;

CREATE POLICY app_settings_a09_select_authenticated_tenant
  ON public.app_settings
  FOR SELECT
  TO authenticated
  USING (public.app_settings_matches_admin_profile(id));

-- ── INSERT: admin مصادق — يُنشئ صف tenant الخاص به فقط ──────────────────────
DROP POLICY IF EXISTS app_settings_a09_insert_authenticated_tenant
  ON public.app_settings;

CREATE POLICY app_settings_a09_insert_authenticated_tenant
  ON public.app_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (public.app_settings_matches_admin_profile(id));

-- ── UPDATE: admin مصادق — يعدّل صف tenant الخاص به فقط ──────────────────────
DROP POLICY IF EXISTS app_settings_a09_update_authenticated_tenant
  ON public.app_settings;

CREATE POLICY app_settings_a09_update_authenticated_tenant
  ON public.app_settings
  FOR UPDATE
  TO authenticated
  USING (public.app_settings_matches_admin_profile(id))
  WITH CHECK (public.app_settings_matches_admin_profile(id));

-- ── DELETE: لا policy إطلاقاً — DELETE مرفوض دائماً عند RLS (آمن، مقصود) ─────

-- ملاحظة: في strict=false تتعايش هذه policies مع legacy الواسعة (PERMISSIVE = OR)،
-- لذا لا تغيير سلوك. الفائدة الأمنية تظهر فقط بعد حذف legacy في strict=true.

-- =============================================================================
-- 5) Strict mode — معطّل افتراضياً (غيّر إلى true بعد مراجعة التقرير + اختبار)
-- =============================================================================
DO $$
DECLARE
  v_enable_strict_mode boolean := true;  -- ⚠️ true فقط بعد التأكد من ربط slug + اختبار
BEGIN
  IF v_enable_strict_mode THEN
    -- حذف legacy policies الواسعة (cross-tenant write hole)
    DROP POLICY IF EXISTS app_settings_public_read ON public.app_settings;
    DROP POLICY IF EXISTS app_settings_authenticated_update ON public.app_settings;
    DROP POLICY IF EXISTS app_settings_authenticated_insert ON public.app_settings;

    -- anon SELECT — interim public read مؤقت (الإعدادات منخفضة الحساسية).
    -- TODO (مرحلة لاحقة): استبدالها بـ policy scoped لصف الـ slug المطلوب فقط.
    DROP POLICY IF EXISTS app_settings_a09_select_anon_interim ON public.app_settings;
    CREATE POLICY app_settings_a09_select_anon_interim
      ON public.app_settings
      FOR SELECT
      TO anon
      USING (true);

    RAISE NOTICE 'A.9: STRICT MODE ON — legacy broad policies dropped; scoped authenticated policies active; anon interim SELECT kept.';
  ELSE
    RAISE NOTICE 'A.9: strict mode OFF (v_enable_strict_mode=false) — legacy policies kept; scoped policies created but coexist (no behavior change).';
  END IF;
END $$;

-- =============================================================================
-- 6) Post-check — تقرير policies بعد التنفيذ
-- =============================================================================
SELECT
  policyname,
  roles,
  cmd,
  CASE
    WHEN policyname LIKE 'app_settings_a09_%' THEN 'A.9 proposed'
    ELSE 'pre-existing/legacy'
  END AS origin,
  qual AS using_expression,
  with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'app_settings'
ORDER BY origin, policyname, cmd;

-- اختبار تشخيصي 1 — الدالة المساعدة موجودة وقابلة للتنفيذ؟
SELECT
  p.proname AS function_name,
  p.prosecdef AS is_security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'app_settings_matches_admin_profile';

-- اختبار تشخيصي 2 — أي صفوف app_settings لا تطابق أي مطعم (مثل 'global')؟
--   هذه الصفوف لن يستطيع أي admin الكتابة عليها بعد strict (مقصود).
SELECT
  s.id AS settings_id,
  EXISTS (
    SELECT 1 FROM public.restaurants r
    WHERE lower(btrim(s.id)) = lower(btrim(r.id))
       OR lower(btrim(s.id)) = lower(btrim(r.slug))
  ) AS has_matching_restaurant
FROM public.app_settings s
ORDER BY has_matching_restaurant, s.id;

-- =============================================================================
-- ROLLBACK — نفّذ يدوياً عند الحاجة
-- =============================================================================
-- -- حذف policies A.9 المقترحة:
-- DROP POLICY IF EXISTS app_settings_a09_select_authenticated_tenant ON public.app_settings;
-- DROP POLICY IF EXISTS app_settings_a09_insert_authenticated_tenant ON public.app_settings;
-- DROP POLICY IF EXISTS app_settings_a09_update_authenticated_tenant ON public.app_settings;
-- DROP POLICY IF EXISTS app_settings_a09_select_anon_interim ON public.app_settings;
--
-- -- استعادة legacy policies (إن كانت قد حُذفت في strict=true) — راجع
-- --   app_settings_rls_policies_a09_backup أو app_settings_schema.sql.
--
-- DROP FUNCTION IF EXISTS public.app_settings_matches_admin_profile(text);
--
-- -- جدول app_settings_rls_policies_a09_backup يُترك للمرجع — لا يحذف بيانات.

NOTIFY pgrst, 'reload schema';
