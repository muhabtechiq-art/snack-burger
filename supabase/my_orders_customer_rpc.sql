-- =============================================================================
-- My Orders — قراءة طلبات الزبون عبر RPC (SECURITY DEFINER)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- مستقل — لا يعدّل C-04 ولا ملفات RLS القديمة (c01_orders_rls_migration.sql)
-- يحل: anon لا يستطيع SELECT مباشر على orders بسبب RLS
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_customer_orders_by_phone(text, text);

CREATE OR REPLACE FUNCTION public.get_customer_orders_by_phone(
  p_slug text,
  p_phone_number text
)
RETURNS TABLE (
  id bigint,
  status text,
  total numeric,
  customer_name text,
  phone_number text,
  delivery_address text,
  notes text,
  created_at timestamptz,
  updated_at timestamptz,
  slug text,
  items jsonb,
  business_day_id uuid
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    o.id::bigint,
    o.status::text,
    o.total_price::numeric AS total,
    o.customer_name::text,
    o.phone_number::text,
    o.address::text AS delivery_address,
    COALESCE(o.rejection_reason, '')::text AS notes,
    o.created_at::timestamptz,
    o.created_at::timestamptz AS updated_at,
    o.slug::text,
    o.order_items::jsonb AS items,
    o.business_day_id::uuid
  FROM public.orders o
  WHERE lower(trim(o.slug)) = lower(trim(p_slug))
    AND trim(o.phone_number) = trim(p_phone_number)
    AND o.created_at >= now() - interval '6 hours'
    AND trim(COALESCE(p_slug, '')) <> ''
    AND trim(COALESCE(p_phone_number, '')) <> ''
  ORDER BY o.created_at DESC
  LIMIT 80;
$$;

COMMENT ON FUNCTION public.get_customer_orders_by_phone(text, text) IS
  'طلباتي — قراءة طلبات الزبون بـ slug + phone خلال 6 ساعات — SECURITY DEFINER';

REVOKE ALL ON FUNCTION public.get_customer_orders_by_phone(text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_customer_orders_by_phone(text, text)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
