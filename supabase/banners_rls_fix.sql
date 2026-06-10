-- إصلاح سياسات RLS لجدول banners — نفّذ في Supabase → SQL Editor
-- شغّل هذا الملف إذا كان التبديل (is_active) لا يُحفظ في قاعدة البيانات.

-- 1) تأكد من وجود العمود
ALTER TABLE public.banners
ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

-- 2) صلاحيات الجدول (مطلوبة مع RLS)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.banners TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.banners TO authenticated;

-- 3) تفعيل RLS
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

-- 4) إزالة سياسات قديمة متعارضة
DROP POLICY IF EXISTS "banners_public_read" ON public.banners;
DROP POLICY IF EXISTS "banners_anon_insert" ON public.banners;
DROP POLICY IF EXISTS "banners_anon_update" ON public.banners;
DROP POLICY IF EXISTS "banners_anon_delete" ON public.banners;
DROP POLICY IF EXISTS "banners_authenticated_update" ON public.banners;

-- 5) سياسات جديدة
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

-- 6) بعد التنفيذ: Settings → API → Reload schema cache
