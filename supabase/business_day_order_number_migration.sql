-- رقم طلب يومي داخل يوم العمل — يبدأ من 1 مع كل يوم مفتوح
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS business_day_order_number integer;

COMMENT ON COLUMN public.orders.business_day_order_number IS
  'رقم تسلسلي داخل يوم العمل (1، 2، 3…) — يُعاد ضبطه عند فتح يوم جديد';

-- تعبئة الطلبات القديمة المربوطة بيوم عمل (حسب created_at)
WITH numbered AS (
  SELECT
    o.id,
    ROW_NUMBER() OVER (
      PARTITION BY o.business_day_id
      ORDER BY o.created_at ASC, o.id ASC
    ) AS rn
  FROM public.orders o
  WHERE o.business_day_id IS NOT NULL
    AND o.business_day_order_number IS NULL
)
UPDATE public.orders o
SET business_day_order_number = numbered.rn
FROM numbered
WHERE o.id = numbered.id;

-- منع تكرار الرقم داخل نفس يوم العمل
CREATE UNIQUE INDEX IF NOT EXISTS orders_business_day_order_number_uq
  ON public.orders (business_day_id, business_day_order_number)
  WHERE business_day_id IS NOT NULL
    AND business_day_order_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS orders_business_day_order_number_idx
  ON public.orders (business_day_id, business_day_order_number DESC);

NOTIFY pgrst, 'reload schema';
