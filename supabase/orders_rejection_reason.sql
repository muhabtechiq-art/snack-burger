-- سبب رفض الطلب — نفّذ في Supabase → SQL Editor
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS rejection_reason text;

COMMENT ON COLUMN public.orders.rejection_reason IS
  'سبب الرفض — يُكمَّل لاحقاً من تبويب الطلبات المرفوضة';

NOTIFY pgrst, 'reload schema';
