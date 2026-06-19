-- ربط الطلبات الحالية غير المرتبطة بيوم العمل المفتوح
-- نفّذ يدوياً في Supabase Dashboard → SQL Editor (لا يُنفَّذ من التطبيق)
-- آمن للمراجعة: شغّل SELECT أولاً ثم UPDATE

-- =============================================================================
-- 1) معاينة الطلبات التي ستُربَط
-- =============================================================================
SELECT
  o.id,
  o.status,
  o.total_price,
  o.slug,
  o.business_day_id,
  o.created_at,
  bd.id AS open_day_id,
  bd.opened_at
FROM public.orders o
INNER JOIN public.business_days bd
  ON bd.status = 'open'
 AND lower(trim(bd.slug)) = 'snack_burger'
WHERE o.business_day_id IS NULL
  AND lower(trim(o.slug)) = 'snack_burger'
  AND o.created_at >= bd.opened_at
  AND o.created_at <= now()
  AND o.status IN (
    'pending',
    'accepted',
    'preparing',
    'delivering',
    'delivered'
  )
ORDER BY o.created_at DESC;

-- =============================================================================
-- 2) الربط الفعلي — يوم العمل المفتوح الحالي فقط
-- =============================================================================
UPDATE public.orders o
SET business_day_id = bd.id
FROM public.business_days bd
WHERE bd.status = 'open'
  AND lower(trim(bd.slug)) = 'snack_burger'
  AND o.business_day_id IS NULL
  AND lower(trim(o.slug)) = 'snack_burger'
  AND o.created_at >= bd.opened_at
  AND o.created_at <= now()
  AND o.status IN (
    'pending',
    'accepted',
    'preparing',
    'delivering',
    'delivered'
  );

-- =============================================================================
-- 3) تحقق بعد التنفيذ
-- =============================================================================
SELECT
  o.id,
  o.status,
  o.business_day_id,
  o.created_at
FROM public.orders o
INNER JOIN public.business_days bd
  ON bd.id = o.business_day_id
 AND bd.status = 'open'
 AND lower(trim(bd.slug)) = 'snack_burger'
ORDER BY o.created_at DESC;
