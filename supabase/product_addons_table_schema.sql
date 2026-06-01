-- إصلاح product_addons: FK + RLS + إعادة تحميل schema
-- نفّذ في Supabase → SQL Editor

-- 1) تأكد من نوع product_id مطابق لـ products.id
-- (عدّل النوع إن لزم — مثال: uuid أو text أو bigint)

-- 2) ربط FK (Cascade) — مطلوب لـ PostgREST ولحذف الإضافات تلقائياً
ALTER TABLE public.product_addons
  DROP CONSTRAINT IF EXISTS product_addons_product_id_fkey;

ALTER TABLE public.product_addons
  ADD CONSTRAINT product_addons_product_id_fkey
  FOREIGN KEY (product_id)
  REFERENCES public.products(id)
  ON DELETE CASCADE;

-- 3) سياسات RLS — بدونها يفشل INSERT/DELETE (42501)
ALTER TABLE public.product_addons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "product_addons_public_read" ON public.product_addons;
DROP POLICY IF EXISTS "product_addons_anon_insert" ON public.product_addons;
DROP POLICY IF EXISTS "product_addons_anon_update" ON public.product_addons;
DROP POLICY IF EXISTS "product_addons_anon_delete" ON public.product_addons;

CREATE POLICY "product_addons_public_read"
ON public.product_addons FOR SELECT TO public USING (true);

CREATE POLICY "product_addons_anon_insert"
ON public.product_addons FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "product_addons_anon_update"
ON public.product_addons FOR UPDATE TO anon, authenticated
USING (true) WITH CHECK (true);

CREATE POLICY "product_addons_anon_delete"
ON public.product_addons FOR DELETE TO anon, authenticated USING (true);

-- 4) إعادة تحميل cache لـ PostgREST (بعد إضافة FK)
NOTIFY pgrst, 'reload schema';
