-- =============================================================================
-- Admin — قراءة كل طلبات يوم العمل (بدون فلتر status) عبر RPC
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- الغرض: إحصائيات يوم العمل (AdminHomeScreen) + التقرير الختامي (closing report)
-- تحتاج كل الحالات (accepted/preparing/delivering/delivered) وليس pending/rejected
-- فقط. SECURITY DEFINER يتجاوز RLS للقراءة ضمن نطاق business_day_id المحدد.
--
-- الفلتر: business_day_id فقط — بدون أي شرط على status.
-- لا يعدّل get_kitchen_dashboard_orders_for_business_day.
-- لا يعدّل close_business_day ولا منطق business_days ولا RLS.
-- آمن للتشغيل المتكرر.
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_business_day_orders_for_admin(uuid);

CREATE OR REPLACE FUNCTION public.get_business_day_orders_for_admin(
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
    AND p_business_day_id IS NOT NULL
  ORDER BY o.created_at DESC;
$$;

COMMENT ON FUNCTION public.get_business_day_orders_for_admin(uuid) IS
  'الإدارة — كل طلبات يوم عمل محدد بـ business_day_id (بدون فلتر status) — SECURITY DEFINER';

REVOKE ALL ON FUNCTION public.get_business_day_orders_for_admin(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_business_day_orders_for_admin(uuid)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
