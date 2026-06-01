-- =============================================================================
-- منيو سناك برجر — إعداد كامل لحفظ موقع الزبون (نفّذ مرة واحدة في Supabase)
-- Dashboard → SQL Editor → New query → الصق هذا الملف بالكامل → Run
-- =============================================================================

-- 1) UUID عشوائي لـ profiles.id (مطلوب لإدراج زبائن بدون حساب Auth)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2) أعمدة موقع التوصيل + فهرس فريد على رقم الهاتف
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_number text,
  ADD COLUMN IF NOT EXISTS last_latitude double precision,
  ADD COLUMN IF NOT EXISTS last_longitude double precision,
  ADD COLUMN IF NOT EXISTS has_saved_location boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_delivery_address text;

-- عمود الدور إن لم يكن موجوداً (لصفوف الزبائن الجدد)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role text;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_number_key
  ON public.profiles (phone_number)
  WHERE phone_number IS NOT NULL;

-- 3) ضبط profiles.id ليقبل gen_random_uuid() عند الإدراج بدون معرّف صريح
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'id'
      AND udt_name = 'uuid'
  ) THEN
    ALTER TABLE public.profiles
      ALTER COLUMN id SET DEFAULT gen_random_uuid();
  ELSE
    RAISE NOTICE
      'تحذير: profiles.id ليس من نوع uuid — راجع نوع العمود قبل تشغيل RPC الإدراج.';
  END IF;
END $$;

-- إذا فشل INSERT لزبون جديد برسالة foreign key على auth.users،
-- فالجدول يربط id بجلسة Auth فقط. عندها أزل القيد (بعد مراجعة أمنية):
-- ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- 4) إزالة سياسات RLS العريضة القديمة (إن وُجدت)
DROP POLICY IF EXISTS "profiles_customer_select_by_phone" ON public.profiles;
DROP POLICY IF EXISTS "profiles_customer_update_by_phone" ON public.profiles;
DROP POLICY IF EXISTS "profiles_customer_insert_customer" ON public.profiles;
DROP POLICY IF EXISTS "profiles_customer_upsert_by_phone" ON public.profiles;

-- 5) RPC — قراءة موقع زبون بالهاتف فقط (بدون SELECT مباشر من التطبيق)
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

-- 6) RPC موحّد — تحديث إن وُجد الهاتف، وإلا إدراج صف زبون (مفتاح: phone_number)
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

-- 7) صلاحيات التنفيذ للتطبيق (زبون anon + مسؤول authenticated)
REVOKE ALL ON FUNCTION public.get_customer_delivery_by_phone(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_customer_location(
  text, double precision, double precision, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_customer_delivery_by_phone(text)
  TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.update_customer_location(
  text, double precision, double precision, text, text
) TO anon, authenticated;

-- إزالة الاسم القديم إن وُجد
DROP FUNCTION IF EXISTS public.upsert_customer_delivery_location(
  text, double precision, double precision, text, text
);

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- تحقق سريع (اختياري — شغّل بعد النجاح):
-- SELECT public.get_customer_delivery_by_phone('07701234567');
-- SELECT column_default FROM information_schema.columns
--   WHERE table_name = 'profiles' AND column_name = 'id';
-- =============================================================================
