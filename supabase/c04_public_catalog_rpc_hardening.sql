-- =============================================================================
-- C-04 — Public Catalog RPC Hardening (منيو الزبون بدون anon SELECT مفتوح)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- النطاق: RPCs للقراءة العامة + إزالة catalog_c02_select_anon_interim (strict)
-- لا يعدّل: orders RLS · storage RLS · catalog_c02 authenticated policies
--
-- ─────────────────────────────────────────────────────────────────────────────
-- ماذا سيحدث عند التنفيذ؟
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) دالة مساعدة c04_resolve_active_restaurant — slug نشط فقط
-- 2) أربع دوال RPC SECURITY DEFINER للمنيو العام
-- 3) v_enable_strict_mode = false (الافتراضي) — لا حذف policies
-- 4) عند strict=true: يحذف catalog_c02_select_anon_interim فقط (4 جداول)
--
-- ─────────────────────────────────────────────────────────────────────────────
-- ترتيب التشغيل
-- ─────────────────────────────────────────────────────────────────────────────
-- Run 1 (strict=false): أنشئ RPCs → حدّث Flutter → اختبر منيو الزبون
-- Run 2 (strict=true):   غيّر v_enable_strict_mode إلى true → نفّذ قسم §7 فقط
--
-- Rollback strict: أعد إنشاء catalog_c02_select_anon_interim من c02 §6
-- =============================================================================

-- =============================================================================
-- 1) تقرير policies anon interim الحالية
-- =============================================================================
SELECT
  tablename,
  policyname,
  roles,
  cmd,
  qual AS using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND policyname = 'catalog_c02_select_anon_interim'
  AND tablename IN ('products', 'product_addons', 'product_variants', 'banners')
ORDER BY tablename;

-- =============================================================================
-- 2) دالة مساعدة — مطعم نشط من slug (أو id نصي يطابق slug)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.c04_resolve_active_restaurant(p_restaurant_slug text)
RETURNS TABLE (
  restaurant_key text,
  restaurant_slug text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_input_slug text;
  v_key text;
  v_slug text;
BEGIN
  v_input_slug := lower(btrim(coalesce(p_restaurant_slug, '')));
  IF v_input_slug = '' THEN
    RAISE EXCEPTION 'invalid_restaurant_slug'
      USING ERRCODE = '22023';
  END IF;

  SELECT r.id::text, r.slug::text
  INTO v_key, v_slug
  FROM public.restaurants r
  WHERE lower(btrim(r.slug)) = v_input_slug
    AND r.is_active = true
  LIMIT 1;

  IF v_key IS NULL THEN
    RAISE EXCEPTION 'restaurant_not_found_or_inactive for slug: %', v_input_slug
      USING ERRCODE = 'P0001';
  END IF;

  restaurant_key := v_key;
  restaurant_slug := v_slug;
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION public.c04_resolve_active_restaurant(text) IS
  'C-04: يحل slug مطعم نشط — restaurant_key = restaurants.id (text)';

REVOKE ALL ON FUNCTION public.c04_resolve_active_restaurant(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.c04_resolve_active_restaurant(text)
  TO anon, authenticated;

-- =============================================================================
-- 3) شرط tenant مشترك — products/banners.restaurant_id
-- =============================================================================
CREATE OR REPLACE FUNCTION public.c04_product_belongs_to_restaurant(
  p_row_restaurant_id text,
  p_restaurant_key text,
  p_restaurant_slug text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT
    p_row_restaurant_id IS NOT NULL
    AND btrim(p_row_restaurant_id) <> ''
    AND (
      lower(btrim(p_row_restaurant_id)) = lower(btrim(p_restaurant_key))
      OR lower(btrim(p_row_restaurant_id)) = lower(btrim(p_restaurant_slug))
    );
$$;

-- =============================================================================
-- 4) RPC — منتجات المنيو العام (حقول آمنة للزبون فقط)
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_public_products(text);

CREATE OR REPLACE FUNCTION public.get_public_products(p_restaurant_slug text)
RETURNS TABLE (
  id bigint,
  restaurant_id text,
  name text,
  description text,
  price numeric,
  image_url text,
  category text,
  variants jsonb,
  is_available boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key text;
  v_slug text;
BEGIN
  SELECT r.restaurant_key, r.restaurant_slug
  INTO v_key, v_slug
  FROM public.c04_resolve_active_restaurant(p_restaurant_slug) r;

  RETURN QUERY
  SELECT
    p.id,
    p.restaurant_id,
    p.name,
    p.description,
    p.price,
    p.image_url,
    p.category,
    coalesce(p.variants, '[]'::jsonb) AS variants,
    p.is_available,
    p.created_at
  FROM public.products p
  WHERE public.c04_product_belongs_to_restaurant(
      p.restaurant_id,
      v_key,
      v_slug
    )
    AND coalesce(p.is_available, true) = true
  ORDER BY p.category, p.name, p.id;
END;
$$;

COMMENT ON FUNCTION public.get_public_products(text) IS
  'C-04: منيو الزبون — منتجات متاحة لمطعم نشط واحد فقط';

REVOKE ALL ON FUNCTION public.get_public_products(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_products(text)
  TO anon, authenticated;

-- =============================================================================
-- 5) RPC — إضافات المنتجات للمنيو العام
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_public_product_addons(text);

CREATE OR REPLACE FUNCTION public.get_public_product_addons(p_restaurant_slug text)
RETURNS TABLE (
  product_id bigint,
  name text,
  price numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key text;
  v_slug text;
BEGIN
  SELECT r.restaurant_key, r.restaurant_slug
  INTO v_key, v_slug
  FROM public.c04_resolve_active_restaurant(p_restaurant_slug) r;

  RETURN QUERY
  SELECT
    a.product_id,
    a.name,
    a.price
  FROM public.product_addons a
  INNER JOIN public.products p ON p.id = a.product_id
  WHERE public.c04_product_belongs_to_restaurant(
      p.restaurant_id,
      v_key,
      v_slug
    )
    AND coalesce(p.is_available, true) = true
  ORDER BY a.product_id, a.name;
END;
$$;

COMMENT ON FUNCTION public.get_public_product_addons(text) IS
  'C-04: إضافات منتجات مطعم نشط — عبر join products';

REVOKE ALL ON FUNCTION public.get_public_product_addons(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_product_addons(text)
  TO anon, authenticated;

-- =============================================================================
-- 6) RPC — أحجام/متغيرات المنتجات للمنيو العام
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_public_product_variants(text);

CREATE OR REPLACE FUNCTION public.get_public_product_variants(p_restaurant_slug text)
RETURNS TABLE (
  id uuid,
  product_id bigint,
  name text,
  price numeric,
  sort_order integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key text;
  v_slug text;
BEGIN
  SELECT r.restaurant_key, r.restaurant_slug
  INTO v_key, v_slug
  FROM public.c04_resolve_active_restaurant(p_restaurant_slug) r;

  RETURN QUERY
  SELECT
    v.id,
    v.product_id,
    v.name,
    v.price,
    v.sort_order
  FROM public.product_variants v
  INNER JOIN public.products p ON p.id = v.product_id
  WHERE public.c04_product_belongs_to_restaurant(
      p.restaurant_id,
      v_key,
      v_slug
    )
    AND coalesce(p.is_available, true) = true
  ORDER BY v.product_id, v.sort_order, v.id;
END;
$$;

COMMENT ON FUNCTION public.get_public_product_variants(text) IS
  'C-04: أحجام منتجات مطعم نشط — عبر join products';

REVOKE ALL ON FUNCTION public.get_public_product_variants(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_product_variants(text)
  TO anon, authenticated;

-- =============================================================================
-- 7) RPC — بانرات المنيو العام (نشطة فقط)
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_public_banners(text);

CREATE OR REPLACE FUNCTION public.get_public_banners(p_restaurant_slug text)
RETURNS TABLE (
  id uuid,
  restaurant_id text,
  image_url text,
  title text,
  is_active boolean,
  sort_order integer,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key text;
  v_slug text;
BEGIN
  SELECT r.restaurant_key, r.restaurant_slug
  INTO v_key, v_slug
  FROM public.c04_resolve_active_restaurant(p_restaurant_slug) r;

  RETURN QUERY
  SELECT
    b.id,
    b.restaurant_id,
    b.image_url,
    b.title,
    b.is_active,
    b.sort_order,
    b.created_at
  FROM public.banners b
  WHERE public.c04_product_belongs_to_restaurant(
      b.restaurant_id,
      v_key,
      v_slug
    )
    AND coalesce(b.is_active, false) = true
  ORDER BY b.sort_order ASC, b.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.get_public_banners(text) IS
  'C-04: بانرات نشطة لمطعم واحد فقط';

REVOKE ALL ON FUNCTION public.get_public_banners(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_banners(text)
  TO anon, authenticated;

-- =============================================================================
-- 8) اختبارات تشخيصية — superuser في SQL Editor
-- =============================================================================
SELECT proname
FROM pg_proc
WHERE proname IN (
  'c04_resolve_active_restaurant',
  'get_public_products',
  'get_public_product_addons',
  'get_public_product_variants',
  'get_public_banners'
)
ORDER BY proname;

-- استبدل slug بمطعمك:
-- SELECT count(*) FROM public.get_public_products('snack_burger');
-- SELECT count(*) FROM public.get_public_product_addons('snack_burger');
-- SELECT count(*) FROM public.get_public_product_variants('snack_burger');
-- SELECT count(*) FROM public.get_public_banners('snack_burger');

-- =============================================================================
-- 9) Strict mode — معطّل افتراضياً
--     يحذف catalog_c02_select_anon_interim فقط (بعد تحديث Flutter + اختبار)
-- =============================================================================
DO $$
DECLARE
  v_enable_strict_mode boolean := false;  -- ⚠️ true فقط بعد نشر Flutter + اختبار منيو الزبون
  v_table text;
BEGIN
  IF v_enable_strict_mode THEN
    RAISE NOTICE 'C-04: STRICT MODE — dropping catalog_c02_select_anon_interim...';

    FOREACH v_table IN ARRAY ARRAY[
      'products',
      'product_addons',
      'product_variants',
      'banners'
    ]
    LOOP
      EXECUTE format(
        'DROP POLICY IF EXISTS catalog_c02_select_anon_interim ON public.%I',
        v_table
      );
      RAISE NOTICE 'C-04: dropped catalog_c02_select_anon_interim on %', v_table;
    END LOOP;
  ELSE
    RAISE NOTICE
      'C-04: v_enable_strict_mode=false — catalog_c02_select_anon_interim KEPT; '
      'Flutter should use get_public_* RPCs for customer menu.';
  END IF;
END $$;

-- =============================================================================
-- 10) تقرير policies بعد التشغيل
-- =============================================================================
SELECT
  tablename,
  policyname,
  roles,
  cmd,
  CASE
    WHEN policyname LIKE 'catalog_c02_%' THEN 'C-02'
    WHEN policyname LIKE 'catalog_c04_%' THEN 'C-04'
    ELSE 'legacy/other'
  END AS origin
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('products', 'product_addons', 'product_variants', 'banners')
ORDER BY tablename, policyname, cmd;

-- =============================================================================
-- ROLLBACK — strict فقط (أعد catalog_c02_select_anon_interim من c02 §6)
-- =============================================================================
-- CREATE POLICY catalog_c02_select_anon_interim ON public.products
--   FOR SELECT TO anon USING (true);
-- (كرّر لـ product_addons, product_variants, banners)
--
-- DROP FUNCTION IF EXISTS public.get_public_banners(text);
-- DROP FUNCTION IF EXISTS public.get_public_product_variants(text);
-- DROP FUNCTION IF EXISTS public.get_public_product_addons(text);
-- DROP FUNCTION IF EXISTS public.get_public_products(text);
-- DROP FUNCTION IF EXISTS public.c04_product_belongs_to_restaurant(text, text, text);
-- DROP FUNCTION IF EXISTS public.c04_resolve_active_restaurant(text);

NOTIFY pgrst, 'reload schema';
