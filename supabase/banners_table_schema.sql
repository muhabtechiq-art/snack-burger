-- جدول بانرات المنيو التفاعلية — Supabase Dashboard → SQL Editor
-- الأعمدة المطلوبة: id, image_url, title, is_active
-- + restaurant_id و sort_order لدعم تعدد المطاعم وترتيب العرض

CREATE TABLE IF NOT EXISTS public.banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id text NOT NULL DEFAULT 'snack_burger',
  image_url text NOT NULL,
  title text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS banners_restaurant_active_idx
  ON public.banners (restaurant_id, is_active, sort_order);

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "banners_public_read" ON public.banners;
DROP POLICY IF EXISTS "banners_anon_insert" ON public.banners;
DROP POLICY IF EXISTS "banners_anon_update" ON public.banners;
DROP POLICY IF EXISTS "banners_anon_delete" ON public.banners;

CREATE POLICY "banners_public_read"
ON public.banners FOR SELECT
TO public
USING (true);

CREATE POLICY "banners_anon_insert"
ON public.banners FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "banners_anon_update"
ON public.banners FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "banners_anon_delete"
ON public.banners FOR DELETE
TO anon, authenticated
USING (true);

-- بعد التنفيذ: فعّل Realtime على الجدول (اختياري للتحديث الفوري):
-- Database → Replication → supabase_realtime → أضف public.banners
-- أو نفّذ:
-- alter publication supabase_realtime add table public.banners;

-- المسار: {restaurant_id}/banners/{banner_id}.jpg
-- راجع: supabase/storage_product_images_policies.sql
