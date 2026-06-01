-- نفّذ بعد customer_location_full_setup.sql إذا بقي الاسم القديم upsert_*
-- أو لتحديث دالة القراءة لإرجاع has_saved_location دائماً

CREATE OR REPLACE FUNCTION public.get_customer_delivery_by_phone(p_phone text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_phone text := trim(coalesce(p_phone, ''));
  result json;
BEGIN
  IF v_phone = '' THEN
    RETURN NULL;
  END IF;

  SELECT json_build_object(
    'phone_number', phone_number,
    'has_saved_location', has_saved_location,
    'last_latitude', last_latitude,
    'last_longitude', last_longitude,
    'last_delivery_address', last_delivery_address
  )
  INTO result
  FROM public.profiles
  WHERE phone_number = v_phone
  LIMIT 1;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_customer_location(
  p_phone text,
  p_latitude double precision,
  p_longitude double precision,
  p_address text DEFAULT NULL,
  p_full_name text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_phone text := trim(coalesce(p_phone, ''));
  v_rows int;
BEGIN
  IF v_phone = '' OR p_latitude IS NULL OR p_longitude IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.profiles
  SET
    last_latitude = p_latitude,
    last_longitude = p_longitude,
    has_saved_location = true,
    last_delivery_address = COALESCE(
      NULLIF(trim(coalesce(p_address, '')), ''),
      last_delivery_address
    ),
    full_name = COALESCE(
      NULLIF(trim(coalesce(p_full_name, '')), ''),
      full_name
    )
  WHERE phone_number = v_phone;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.profiles (
    id,
    phone_number,
    last_latitude,
    last_longitude,
    has_saved_location,
    last_delivery_address,
    full_name,
    role
  )
  VALUES (
    gen_random_uuid(),
    v_phone,
    p_latitude,
    p_longitude,
    true,
    NULLIF(trim(coalesce(p_address, '')), ''),
    NULLIF(trim(coalesce(p_full_name, '')), ''),
    'customer'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_customer_location(
  text, double precision, double precision, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_customer_location(
  text, double precision, double precision, text, text
) TO anon, authenticated;

DROP FUNCTION IF EXISTS public.upsert_customer_delivery_location(
  text, double precision, double precision, text, text
);

NOTIFY pgrst, 'reload schema';
