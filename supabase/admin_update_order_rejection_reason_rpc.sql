-- =============================================================================
-- Admin — حفظ سبب رفض الطلب عبر RPC آمن (بديل عن update المباشر)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor
--
-- لماذا؟ update المباشر على public.orders يخضع لـ RLS؛ وقد يتأثر 0 صف بلا أي خطأ
-- (no-op صامت) فتبدو الواجهة "تم الحفظ" بينما يبقى rejection_reason = NULL.
-- هذه الدالة SECURITY DEFINER تتجاوز RLS بأمان وتُرجِع الصف المُحدَّث للتحقق الفعلي،
-- مع التحقق من: وجود الطلب + ملكية المستأجر.
--
-- لا يعدّل RLS ولا الدوال الأخرى. آمن للتشغيل المتكرر.
-- =============================================================================

DROP FUNCTION IF EXISTS public.admin_update_order_rejection_reason(bigint, text);

CREATE OR REPLACE FUNCTION public.admin_update_order_rejection_reason(
  p_order_id bigint,
  p_rejection_reason text
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
  v_restaurant_id text;
  v_slug text;
  v_reason text;
BEGIN
  -- (6) خزّن السبب بعد trim — فارغ ⇒ NULL
  v_reason := NULLIF(btrim(coalesce(p_rejection_reason, '')), '');

  -- تأكد أن الطلب موجود + اقفله للتحديث
  SELECT o.restaurant_id::text, o.slug::text
  INTO v_restaurant_id, v_slug
  FROM public.orders o
  WHERE o.id = p_order_id
  FOR UPDATE;

  -- (5) غير موجود ⇒ order_forbidden
  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_forbidden: %', p_order_id
      USING ERRCODE = '42501';
  END IF;

  -- (4/5) تحقق من ملكية المستأجر عبر helper الـ RLS الحالي على orders
  IF NOT public.orders_matches_admin_profile(v_restaurant_id, v_slug) THEN
    RAISE EXCEPTION 'order_forbidden: %', p_order_id
      USING ERRCODE = '42501';
  END IF;

  -- (7) تحديث سبب الرفض فقط
  UPDATE public.orders o
  SET rejection_reason = v_reason
  WHERE o.id = p_order_id;

  -- (8) أرجع الصف المُحدَّث بأعمدة DeliveryOrder الأساسية (نفس admin_update_order_status)
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

COMMENT ON FUNCTION public.admin_update_order_rejection_reason(bigint, text) IS
  'بديل آمن عن update المباشر المتأثر بـ RLS — يحفظ سبب رفض الطلب مع تحقق من '
  'وجود الطلب + ملكية المستأجر، ويُرجِع الصف المُحدَّث — SECURITY DEFINER';

REVOKE ALL ON FUNCTION public.admin_update_order_rejection_reason(bigint, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_update_order_rejection_reason(bigint, text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
