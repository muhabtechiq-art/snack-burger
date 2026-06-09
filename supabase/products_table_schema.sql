-- إكمال جدول products ليتوافق مع التطبيق
-- نفّذ في: Supabase Dashboard → SQL Editor

-- عمود التصنيف (السبب المباشر لخطأ PGRST204)
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'general';

-- أعمدة إضافية يستخدمها التطبيق
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS restaurant_id text DEFAULT 'snack_burger';

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS addons jsonb DEFAULT '[]'::jsonb;

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS is_available boolean NOT NULL DEFAULT true;

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- إن لم يكن image_url موجوداً
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS image_url text;

-- إن لم يكن description موجوداً
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS description text;

-- أحجام المنتج (fallback jsonb — يقرأها المنيو إن لم يوجد جدول product_variants)
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS variants jsonb DEFAULT '[]'::jsonb;

-- RLS: السماح بالإدراج والتحديث والقراءة (مثل orders)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "products_public_read" ON public.products;
DROP POLICY IF EXISTS "products_anon_insert" ON public.products;
DROP POLICY IF EXISTS "products_anon_update" ON public.products;

CREATE POLICY "products_public_read"
ON public.products FOR SELECT
TO public
USING (true);

CREATE POLICY "products_anon_insert"
ON public.products FOR INSERT
TO anon, authenticated
WITH CHECK (true);

CREATE POLICY "products_anon_update"
ON public.products FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "products_anon_delete" ON public.products;

CREATE POLICY "products_anon_delete"
ON public.products FOR DELETE
TO anon, authenticated
USING (true);

-- بعد التعديل: Settings → API → Reload schema cache (أو انتظر دقيقة)
