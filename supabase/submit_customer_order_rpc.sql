-- RPC إنشاء طلب زبون — يربط الطلب بيوم العمل المفتوح ذرياً
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor (لا يُنفَّذ من التطبيق)
-- آمن للتشغيل المتكرر — لا يحذف policies ولا بيانات

DROP FUNCTION IF EXISTS public.submit_customer_order(
  text,
  text,
  text,
  text,
  text,
  numeric,
  jsonb,
  text
);

CREATE FUNCTION public.submit_customer_order(
  p_restaurant_id text,
  p_slug text,
  p_customer_name text,
  p_phone_number text,
  p_address text,
  p_total_price numeric,
  p_order_items jsonb,
  p_location_coordinates text DEFAULT NULL
)
RETURNS TABLE (
  id bigint,
  business_day_id uuid,
  status text,
  slug text,
  business_day_order_number integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_restaurant_id text;
  v_slug text;
  v_open_day_id uuid;
  v_day_order_number integer;
BEGIN
  v_restaurant_id := lower(trim(p_restaurant_id));
  v_slug := lower(trim(p_slug));

  IF v_restaurant_id = '' OR v_slug = '' THEN
    RAISE EXCEPTION 'invalid_restaurant_scope'
      USING ERRCODE = '22023';
  END IF;

  IF trim(p_customer_name) = ''
     OR trim(p_phone_number) = ''
     OR trim(p_address) = '' THEN
    RAISE EXCEPTION 'invalid_order_fields'
      USING ERRCODE = '22023';
  END IF;

  IF p_total_price IS NULL OR p_total_price < 0 THEN
    RAISE EXCEPTION 'invalid_total_price'
      USING ERRCODE = '22023';
  END IF;

  IF p_order_items IS NULL OR jsonb_typeof(p_order_items) <> 'array' THEN
    RAISE EXCEPTION 'invalid_order_items'
      USING ERRCODE = '22023';
  END IF;

  -- قفل صف يوم العمل المفت open — يُسلسل الطلبات المتزامنة على نفس اليوم
  SELECT bd.id
  INTO v_open_day_id
  FROM public.business_days bd
  WHERE bd.restaurant_id = v_restaurant_id
    AND bd.status = 'open'
  ORDER BY bd.opened_at DESC
  LIMIT 1
  FOR UPDATE;

  IF v_open_day_id IS NULL THEN
    RAISE EXCEPTION 'no_open_business_day'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(MAX(o.business_day_order_number), 0) + 1
  INTO v_day_order_number
  FROM public.orders o
  WHERE o.business_day_id = v_open_day_id;

  RETURN QUERY
  INSERT INTO public.orders (
    customer_name,
    phone_number,
    address,
    total_price,
    order_items,
    status,
    slug,
    business_day_id,
    business_day_order_number,
    location_coordinates
  )
  VALUES (
    trim(p_customer_name),
    trim(p_phone_number),
    trim(p_address),
    p_total_price,
    p_order_items,
    'pending',
    v_slug,
    v_open_day_id,
    v_day_order_number,
    NULLIF(trim(p_location_coordinates), '')
  )
  RETURNING
    orders.id::bigint,
    orders.business_day_id::uuid,
    orders.status::text,
    orders.slug::text,
    orders.business_day_order_number::integer;
END;
$$;

COMMENT ON FUNCTION public.submit_customer_order(
  text, text, text, text, text, numeric, jsonb, text
) IS
  'إنشاء طلب pending مربوط بيوم العمل المفتوح مع رقم يومي — SECURITY DEFINER';

REVOKE ALL ON FUNCTION public.submit_customer_order(
  text, text, text, text, text, numeric, jsonb, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.submit_customer_order(
  text, text, text, text, text, numeric, jsonb, text
) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
