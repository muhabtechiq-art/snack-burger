-- Supabase Storage — bucket: daily-sounds
-- نفّذ يدوياً في: Supabase Dashboard → SQL Editor
--
-- قبل التنفيذ:
-- 1. Storage → New bucket → الاسم: daily-sounds
-- 2. فعّل "Public bucket" لعرض الملفات عبر getPublicUrl
--    (أو نفّذ INSERT أدناه إن لم يكن الـ bucket موجوداً)

INSERT INTO storage.buckets (id, name, public)
VALUES ('daily-sounds', 'daily-sounds', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

DROP POLICY IF EXISTS "daily_sounds_public_read" ON storage.objects;
DROP POLICY IF EXISTS "daily_sounds_anon_insert" ON storage.objects;
DROP POLICY IF EXISTS "daily_sounds_anon_update" ON storage.objects;
DROP POLICY IF EXISTS "daily_sounds_anon_delete" ON storage.objects;

-- قراءة عامة (تشغيل الصوت في واجهة الزبون)
CREATE POLICY "daily_sounds_public_read"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'daily-sounds');

-- رفع ملفات صوت (INSERT)
CREATE POLICY "daily_sounds_anon_insert"
ON storage.objects
FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'daily-sounds');

-- استبدال ملف موجود (upsert)
CREATE POLICY "daily_sounds_anon_update"
ON storage.objects
FOR UPDATE
TO anon, authenticated
USING (bucket_id = 'daily-sounds')
WITH CHECK (bucket_id = 'daily-sounds');

-- حذف ملف صوت
CREATE POLICY "daily_sounds_anon_delete"
ON storage.objects
FOR DELETE
TO anon, authenticated
USING (bucket_id = 'daily-sounds');
