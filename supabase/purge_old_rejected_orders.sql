-- حذف الطلبات المرفوضة الأقدم من اليوم المحلي (Asia/Baghdad)
-- نفّذ في Supabase → SQL Editor

CREATE OR REPLACE FUNCTION public.purge_old_rejected_orders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
  today_local date;
BEGIN
  today_local := (timezone('Asia/Baghdad', now()))::date;

  DELETE FROM public.orders o
  WHERE lower(trim(o.status)) = 'rejected'
    AND (timezone('Asia/Baghdad', o.created_at))::date < today_local;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_old_rejected_orders() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_old_rejected_orders() TO anon, authenticated;
