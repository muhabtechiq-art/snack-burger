-- سياسات RLS لجدول profiles — نفّذ في Supabase SQL Editor

alter table public.profiles enable row level security;

-- المسؤول يقرأ ملفه فقط
create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

-- (اختياري) إدراج/تحديث الذاتي
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());
