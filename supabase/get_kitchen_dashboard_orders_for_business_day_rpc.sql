-- =============================================================================
-- Kitchen Dashboard — قراءة طلبات لوحة الكاشير ليوم عمل محدد عبر RPC
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- يحل: لوحة الكاشير تعتمد على .from('orders').stream() الذي يعيد 0 صف بسبب RLS.
-- SECURITY DEFINER يتجاوز RLS للقراءة فقط ضمن نطاق business_day_id المحدد.
--
-- الفلترة: business_day_id فقط + status IN ('pending','rejected).
-- لا يستخدم restaurant_id إطلاقاً (حسب المتطلبات).
-- لا يعدّل submit_customer_order ولا منطق business_days.
-- آمن للتشغيل المتكرر.
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_kitchen_dashboard_orders_for_business_day(uuid);

CREATE OR REPLACE FUNCTION public.get_kitchen_dashboard_orders_for_business_day(
  p_business_day_id uuid
)
RETURNS TABLE (
  id bigint,
  restaurant_id text,
  slug text,
  customer_name text,
  phone_number text,
  address text,
  total_price numeric,
  order_items jsonb,
  status text,
  rejection_reason text,
  business_day_id uuid,
  business_day_order_number integer,
  location_coordinates text,
  created_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    o.id::bigint,
    o.restaurant_id::text,
    o.slug::text,
    o.customer_name::text,
    o.phone_number::text,
    o.address::text,
    o.total_price::numeric,
    o.order_items::jsonb,
    o.status::text,
    o.rejection_reason::text,
    o.business_day_id::uuid,
    o.business_day_order_number::integer,
    o.location_coordinates::text,
    o.created_at::timestamptz
  FROM public.orders o
  WHERE o.business_day_id = p_business_day_id
    AND o.status IN ('pending', 'rejected')
    AND p_business_day_id IS NOT NULL
  ORDER BY o.created_at DESC;
$$;

COMMENT ON FUNCTION public.get_kitchen_dashboard_orders_for_business_day(uuid) IS
  'لوحة الكاشير — طلبات pending/rejected ليوم عمل محدد بـ business_day_id فقط — SECURITY DEFINER';

REVOKE ALL ON FUNCTION public.get_kitchen_dashboard_orders_for_business_day(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_kitchen_dashboard_orders_for_business_day(uuid)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
