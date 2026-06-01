-- سياسات Supabase Storage لـ bucket: product-images
-- نفّذ في: Supabase Dashboard → SQL Editor
--
-- قبل التنفيذ:
-- 1. Storage → product-images → تأكد أن الـ bucket موجود
-- 2. فعّل "Public bucket" لعرض الصور عبر getPublicUrl

-- إزالة سياسات قديمة بنفس الاسم (إن وُجدت)
DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
DROP POLICY IF EXISTS "product_images_anon_insert" ON storage.objects;
DROP POLICY IF EXISTS "product_images_anon_update" ON storage.objects;

-- قراءة عامة (عرض الصور في المنيو)
CREATE POLICY "product_images_public_read"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- رفع صور (INSERT) — التطبيق يستخدم anon key
CREATE POLICY "product_images_anon_insert"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'product-images');

-- تحديث/استبدال (upsert: true)
CREATE POLICY "product_images_anon_update"
ON storage.objects
FOR UPDATE
TO anon, authenticated
USING (bucket_id = 'product-images')
WITH CHECK (bucket_id = 'product-images');
