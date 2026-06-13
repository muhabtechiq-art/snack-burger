-- مواءمة أسماء معاملات RPC مع التطبيق: phone_number, lat, lng, address
-- نفّذ في Supabase SQL Editor إذا ظهر خطأ "parameter not found"

DROP FUNCTION IF EXISTS public.update_customer_location(
  text, double precision, double precision, text, text
);
DROP FUNCTION IF EXISTS public.update_customer_location(
  text, double precision, double precision, text
);

CREATE OR REPLACE FUNCTION public.get_customer_delivery_by_phone(phone_number text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_phone text := trim(coalesce(phone_number, ''));
  result json;
BEGIN
  IF v_phone = '' THEN
    RETURN NULL;
  END IF;

  SELECT json_build_object(
    'phone_number', profiles.phone_number,
    'has_saved_location', profiles.has_saved_location,
    'last_latitude', profiles.last_latitude,
    'last_longitude', profiles.last_longitude,
    'last_delivery_address', profiles.last_delivery_address
  )
  INTO result
  FROM public.profiles
  WHERE profiles.phone_number = v_phone
  LIMIT 1;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_customer_location(
  phone_number text,
  lat double precision,
  lng double precision,
  address text DEFAULT NULL,
  restaurant_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_phone text := trim(coalesce(phone_number, ''));
  v_restaurant_id text := trim(coalesce(restaurant_id, ''));
  v_rows int;
BEGIN
  IF v_phone = '' OR lat IS NULL OR lng IS NULL OR v_restaurant_id = '' THEN
    RETURN;
  END IF;

  UPDATE public.profiles
  SET
    last_latitude = lat,
    last_longitude = lng,
    has_saved_location = true,
    last_delivery_address = COALESCE(
      NULLIF(trim(coalesce(address, '')), ''),
      last_delivery_address
    ),
    restaurant_id = v_restaurant_id
  WHERE profiles.phone_number = v_phone;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.profiles (
    id,
    phone_number,
    restaurant_id,
    last_latitude,
    last_longitude,
    has_saved_location,
    last_delivery_address,
    role
  )
  VALUES (
    gen_random_uuid(),
    v_phone,
    v_restaurant_id,
    lat,
    lng,
    true,
    NULLIF(trim(coalesce(address, '')), ''),
    'customer'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_delivery_by_phone(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_customer_location(
  text, double precision, double precision, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_customer_delivery_by_phone(text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_customer_location(
  text, double precision, double precision, text, text
) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
