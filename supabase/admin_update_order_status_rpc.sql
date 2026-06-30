-- =============================================================================
-- Admin — تحديث حالة الطلب عبر RPC آمن (بديل عن update المباشر)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- لماذا؟ update المباشر على public.orders يخضع لـ RLS؛ وقد يتأثر 0 صف بلا أي خطأ
-- (no-op صامت) فتبدو الواجهة ناجحة بينما يبقى status كما هو في القاعدة.
-- هذه الدالة SECURITY DEFINER تتجاوز RLS بأمان وتُرجِع الصف المُحدَّث للتحقق الفعلي،
-- مع التحقق من: الحالة المسموحة + وجود الطلب + ملكية المستأجر.
--
-- لا يعدّل RLS ولا الدوال الأخرى. آمن للتشغيل المتكرر.
-- =============================================================================

DROP FUNCTION IF EXISTS public.admin_update_order_status(bigint, text);

CREATE OR REPLACE FUNCTION public.admin_update_order_status(
  p_order_id bigint,
  p_status text
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
VOLATILE
AS $$
DECLARE
  v_status text;
  v_restaurant_id text;
  v_slug text;
BEGIN
  v_status := lower(btrim(coalesce(p_status, '')));

  -- (10) الحالة المسموحة فقط
  IF v_status NOT IN (
    'accepted', 'preparing', 'delivering', 'delivered', 'rejected'
  ) THEN
    RAISE EXCEPTION 'invalid_order_status: %', p_status
      USING ERRCODE = '22023';
  END IF;

  -- (7/9) تأكد أن الطلب موجود + اقفله للتحديث
  SELECT o.restaurant_id::text, o.slug::text
  INTO v_restaurant_id, v_slug
  FROM public.orders o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found: %', p_order_id
      USING ERRCODE = 'P0002';
  END IF;

  -- (8/11) تحقق من ملكية المستأجر عبر helper الـ RLS الحالي على orders
  IF NOT public.orders_matches_admin_profile(v_restaurant_id, v_slug) THEN
    RAISE EXCEPTION 'order_forbidden: %', p_order_id
      USING ERRCODE = '42501';
  END IF;

  -- (12) تحديث الحالة فقط (لا updated_at — غير موجود)
  UPDATE public.orders o
  SET status = v_status
  WHERE o.id = p_order_id;

  -- (13) أرجع الصف المُحدَّث بأعمدة DeliveryOrder الأساسية
  RETURN QUERY
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
  WHERE o.id = p_order_id;
END;
$$;

COMMENT ON FUNCTION public.admin_update_order_status(bigint, text) IS
  'بديل آمن عن update المباشر المتأثر بـ RLS — يحدّث حالة الطلب مع تحقق من '
  'الحالة المسموحة + وجود الطلب + ملكية المستأجر، ويُرجِع الصف المُحدَّث — SECURITY DEFINER';

REVOKE ALL ON FUNCTION public.admin_update_order_status(bigint, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_update_order_status(bigint, text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
