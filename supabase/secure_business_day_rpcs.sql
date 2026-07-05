-- =============================================================================
-- Secure open/close business day RPCs — tenant check via profiles
-- Manual run only: Supabase Dashboard → SQL Editor
-- Branch intent: saas-v2
--
-- Prerequisites:
--   - public.business_days + original RPCs (business_days_schema.sql)
--   - public.orders_matches_admin_profile(text, text) (c01_orders_rls_migration.sql)
--
-- Does NOT change:
--   - Function signatures (Flutter unchanged)
--   - business_days RLS policies (including public_read_open)
--   - business_days_schema.sql
-- =============================================================================

CREATE OR REPLACE FUNCTION public.open_business_day(
  p_restaurant_id text,
  p_slug text
)
RETURNS public.business_days
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_restaurant_id text;
  v_slug text;
  v_row public.business_days;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required'
      USING ERRCODE = '42501';
  END IF;

  v_restaurant_id := lower(trim(p_restaurant_id));
  v_slug := trim(p_slug);

  IF v_restaurant_id = '' OR v_slug = '' THEN
    RAISE EXCEPTION 'invalid_restaurant_scope'
      USING ERRCODE = '22023';
  END IF;

  IF NOT public.orders_matches_admin_profile(v_restaurant_id, v_slug) THEN
    RAISE EXCEPTION 'business_day_forbidden'
      USING ERRCODE = '42501';
  END IF;

  -- قفل على مستوى المطعم — يمنع race condition بين جهازين
  PERFORM pg_advisory_xact_lock(hashtext(v_restaurant_id));

  IF EXISTS (
    SELECT 1
    FROM public.business_days bd
    WHERE bd.restaurant_id = v_restaurant_id
      AND bd.status = 'open'
  ) THEN
    RAISE EXCEPTION 'business_day_already_open'
      USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.business_days (
    restaurant_id,
    slug,
    status,
    opened_at,
    opened_by,
    updated_at
  )
  VALUES (
    v_restaurant_id,
    v_slug,
    'open',
    now(),
    auth.uid(),
    now()
  )
  RETURNING * INTO v_row;

  RETURN v_row;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'business_day_already_open'
      USING ERRCODE = '23505';
END;
$$;

COMMENT ON FUNCTION public.open_business_day(text, text) IS
  'يفتح يوم عمل جديد — tenant-scoped عبر orders_matches_admin_profile';

CREATE OR REPLACE FUNCTION public.close_business_day(
  p_restaurant_id text,
  p_notes text DEFAULT NULL
)
RETURNS public.business_days
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_restaurant_id text;
  v_row public.business_days;
  v_order_count integer;
  v_total_sales numeric(12, 2);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required'
      USING ERRCODE = '42501';
  END IF;

  v_restaurant_id := lower(trim(p_restaurant_id));

  IF v_restaurant_id = '' THEN
    RAISE EXCEPTION 'invalid_restaurant_scope'
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(v_restaurant_id));

  SELECT *
  INTO v_row
  FROM public.business_days bd
  WHERE bd.restaurant_id = v_restaurant_id
    AND bd.status = 'open'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'no_open_business_day'
      USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.orders_matches_admin_profile(v_row.restaurant_id, v_row.slug) THEN
    RAISE EXCEPTION 'business_day_forbidden'
      USING ERRCODE = '42501';
  END IF;

  SELECT
    count(*)::integer,
    coalesce(sum(o.total_price), 0)::numeric(12, 2)
  INTO v_order_count, v_total_sales
  FROM public.orders o
  WHERE o.business_day_id = v_row.id
    AND lower(trim(o.status)) IN (
      'accepted',
      'preparing',
      'delivering',
      'delivered'
    );

  UPDATE public.business_days bd
  SET
    status = 'closed',
    closed_at = now(),
    closed_by = auth.uid(),
    closed_order_count = v_order_count,
    closed_total_sales = v_total_sales,
    notes = nullif(trim(p_notes), ''),
    updated_at = now()
  WHERE bd.id = v_row.id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

COMMENT ON FUNCTION public.close_business_day(text, text) IS
  'يغلق يوم العمل المفتوح — tenant-scoped عبر orders_matches_admin_profile';

REVOKE ALL ON FUNCTION public.open_business_day(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.open_business_day(text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.close_business_day(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.close_business_day(text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
