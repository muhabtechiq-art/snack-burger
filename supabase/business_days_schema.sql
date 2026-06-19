-- Manual Business Day — Migration (نسخة نهائية)
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor (لا يُنفَّذ من التطبيق)
-- آمن للتشغيل المتكرر — لا يحذف بيانات

-- =============================================================================
-- 1) جدول أيام العمل
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.business_days (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id text NOT NULL,
  slug text NOT NULL,
  status text NOT NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  opened_by uuid REFERENCES auth.users(id),
  closed_by uuid REFERENCES auth.users(id),
  notes text,
  closed_order_count integer,
  closed_total_sales numeric(12, 2),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_days_status_check CHECK (
    status IN ('open', 'closed')
  ),
  CONSTRAINT business_days_restaurant_id_not_blank CHECK (
    length(trim(restaurant_id)) > 0
  ),
  CONSTRAINT business_days_slug_not_blank CHECK (
    length(trim(slug)) > 0
  ),
  CONSTRAINT business_days_closed_at_check CHECK (
    (status = 'open' AND closed_at IS NULL)
    OR (status = 'closed' AND closed_at IS NOT NULL)
  ),
  CONSTRAINT business_days_closed_stats_check CHECK (
    status = 'open'
    OR (
      closed_order_count IS NOT NULL
      AND closed_total_sales IS NOT NULL
    )
  )
);

COMMENT ON TABLE public.business_days IS
  'سجل أيام العمل اليدوية — الفتح/الإغلاق عبر RPC فقط';

COMMENT ON COLUMN public.business_days.restaurant_id IS
  'نطاق المطعم — lower(trim) كما في Flutter (AdminOrderRepository.resolveRestaurantId)';

COMMENT ON COLUMN public.business_days.slug IS
  'slug المطعم في الرابط — مثل snack_burger';

COMMENT ON COLUMN public.business_days.status IS
  'open = يوم عمل مفتوح | closed = يوم مغلق';

COMMENT ON COLUMN public.business_days.opened_at IS
  'وقت فتح يوم العمل — يُسجَّل عند RPC open_business_day';

COMMENT ON COLUMN public.business_days.closed_at IS
  'وقت إغلاق يوم العمل — يُسجَّل عند RPC close_business_day';

COMMENT ON COLUMN public.business_days.closed_order_count IS
  'لقطة عدد الطلبات المحتسبة عند الإغلاق';

COMMENT ON COLUMN public.business_days.closed_total_sales IS
  'لقطة إجمالي المبيعات المحتسبة عند الإغلاق';

-- =============================================================================
-- 2) فهارس — يمنع يومين مفتوحين لنفس restaurant_id
-- =============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS business_days_one_open_per_restaurant
  ON public.business_days (restaurant_id)
  WHERE status = 'open';

CREATE INDEX IF NOT EXISTS business_days_restaurant_status_idx
  ON public.business_days (restaurant_id, status);

CREATE INDEX IF NOT EXISTS business_days_restaurant_opened_idx
  ON public.business_days (restaurant_id, opened_at DESC);

CREATE INDEX IF NOT EXISTS business_days_slug_status_idx
  ON public.business_days (slug, status);

-- =============================================================================
-- 3) ربط الطلبات بيوم العمل
-- =============================================================================
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS business_day_id uuid
  REFERENCES public.business_days(id);

CREATE INDEX IF NOT EXISTS orders_business_day_id_idx
  ON public.orders (business_day_id);

CREATE INDEX IF NOT EXISTS orders_business_day_status_idx
  ON public.orders (business_day_id, status)
  WHERE business_day_id IS NOT NULL;

COMMENT ON COLUMN public.orders.business_day_id IS
  'يربط الطلب بيوم العمل المفتوح وقت الإنشاء';

-- =============================================================================
-- 4) RLS — قراءة فقط من العميل؛ الكتابة عبر RPC (SECURITY DEFINER)
-- =============================================================================
ALTER TABLE public.business_days ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS business_days_authenticated_all ON public.business_days;
DROP POLICY IF EXISTS business_days_authenticated_read ON public.business_days;
DROP POLICY IF EXISTS business_days_public_read_open ON public.business_days;

CREATE POLICY business_days_authenticated_read
  ON public.business_days
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY business_days_public_read_open
  ON public.business_days
  FOR SELECT
  TO public
  USING (status = 'open');

-- =============================================================================
-- 5) RPC — فتح يوم العمل (Atomic)
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
  'يفتح يوم عمل جديد — يوم واحد مفتوح فقط لكل restaurant_id';

-- =============================================================================
-- 6) RPC — إغلاق يوم العمل (Atomic + حساب الإحصائيات)
-- =============================================================================
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
  'يغلق يوم العمل المفتوح ويحفظ لقطة الطلبات والمبيعات';

-- =============================================================================
-- 7) صلاحيات RPC
-- =============================================================================
REVOKE ALL ON FUNCTION public.open_business_day(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.open_business_day(text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.close_business_day(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.close_business_day(text, text) TO authenticated;

-- =============================================================================
-- 8) Realtime — تزامن حالة يوم العمل بين الأجهزة
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'business_days'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.business_days;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
